let context = #{};

// This generally comes from ANSWERS, but prompting for it ensures it is in the context 
context += prompt("Project Author:", "author_full", #{
    placeholder: "Your Name <your.name@example.com>",
});

context += prompt("Org Name:", "org-name", #{
  placeholder: "Acme",
  cased_as: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
    FixedKeyCasedValue("org-title", TitleCase),
  ],
  help: "Organization Name",
});

context += prompt("Solution Name:", "solution-name", #{
  placeholder: "API",
  cased_as: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
    FixedKeyCasedValue("solution-title", TitleCase),
  ],
  help: "Solution Name",
});

context += set("org-solution-name", render("{{ org-name }}-{{ solution-name }}", context), #{
  cases: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
  ],
});

context += prompt("Project Prefix:", "prefix-name", #{
  placeholder: "User",
  cased_as: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
    FixedKeyCasedValue("project-title", TitleCase),
  ],
  help: "Business Domain/Resource Name",
});

context += prompt("Project Suffix:", "suffix-name", #{
  defaults_with: "Service",
  cased_as: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
    FixedKeyCasedValue("suffix-title", TitleCase),
  ],
  help: "Project Type (e.g., Service, API)",
});

// Application shape. Drives which profile overlay renders on top of the shared
// platform wiring (CI/CD + Kubernetes base). Keep contents/base/ shape-agnostic;
// add a profile by creating contents/<profile>/ and a branch in the render section.
context += prompt("Application Type:", "app-type", #{
  defaults_with: "REST API",
  type: Select([
    "REST API",
    "Background Worker",
    "Scheduled Task",
  ]),
  help: "REST API = FastAPI/uvicorn HTTP service. Background Worker = headless long-running process (no HTTP). Scheduled Task = run-to-completion job on a cron (PlatformTask).",
});

// --- HTTP-shape prompts (REST API only) ---
if context["app-type"] == "REST API" {
  context += prompt("HTTP Port:", "port", #{
    defaults_with: "8080",
    help: "Container port the service listens on; also the readiness-probe port.",
  });
  context += prompt("Ingress (external exposure):", "ingress", #{
    defaults_with: "Internal (cluster only)",
    type: Select([
      "Internal (cluster only)",
      "Public + OIDC",
      "Public (no auth)",
    ]),
    help: "Internal = reachable only inside the cluster. Public = exposed via ingress; prefer OIDC unless the endpoint is truly public.",
  });
  context += prompt("Allow Alloy to scrape metrics?", "metrics", #{
    defaults_with: "Yes",
    type: Select(["Yes", "No"]),
    help: "Adds an inbound rule letting the alloy namespace reach your /metrics endpoint.",
  });
}

// --- Schedule prompt (Scheduled Task only) ---
if context["app-type"] == "Scheduled Task" {
  context += prompt("Cron Schedule:", "schedule", #{
    defaults_with: "0 2 * * *",
    help: "Cron expression (UTC) for when the task runs. '0 2 * * *' = daily at 02:00.",
  });
}

// --- Data & connectivity prompts (long-running profiles) ---
if context["app-type"] != "Scheduled Task" {
  context += prompt("Database:", "database", #{
    defaults_with: "None",
    type: Select([
      "None",
      "CockroachDB (platform-managed)",
      "External (bring your own URL)",
    ]),
    help: "CockroachDB = platform provisions one and injects credentials. External = you supply a connection string (move it to a secret for production).",
  });
  if context["database"] == "External (bring your own URL)" {
    context += prompt("Database URL:", "database_url", #{
      defaults_with: "postgresql+asyncpg://user:password@host:5432/dbname",
      help: "Your connection string. For production, replace with a secret reference.",
    });
  }
  context += prompt("Object storage (Azure Blob)?", "object_storage", #{
    defaults_with: "No",
    type: Select(["No", "Yes"]),
    help: "Requests a platform-managed Azure Blob container with read/write access.",
  });
  context += prompt("Egress (outbound) policy:", "egress", #{
    defaults_with: "Open (allow all)",
    type: Select([
      "Open (allow all)",
      "Restricted (allow-list)",
    ]),
    help: "Open = no outbound restriction. Restricted = only listed hosts are reachable (Istio ServiceEntry).",
  });
  if context["egress"] == "Restricted (allow-list)" {
    context += prompt("Allowed egress hosts:", "egress_hosts", #{
      defaults_with: ["api.anthropic.com"],
      type: List,
      help: "External hostnames this app may call (e.g. api.anthropic.com).",
    });
  }
}

context += set("project-name", render("{{ prefix-name }}-{{ suffix-name }}", context), #{
  cases: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
  ],
});

// Profile-specific files FIRST. archetect render is first-write-wins, so the
// profile's version of any shared-path file (e.g. a Scheduled Task's PlatformTask
// application-customizations.yaml and env patches) takes precedence; base only
// fills in paths the profile didn't provide.
if context["app-type"] == "Background Worker" {
  render(Directory("contents/worker"), context);
} else if context["app-type"] == "Scheduled Task" {
  render(Directory("contents/task"), context);
} else {
  render(Directory("contents/rest-api"), context);
}

// Then the shared, shape-agnostic wiring (CI/CD workflows, Kubernetes kustomize base).
render(Directory("contents/base"), context);

//
// Publishing
//
if switch_enabled("zip") {
  zip(context["project-name"], render("{{ project-name }}.zip", context));
}
if switch_enabled("tarball") {
  tar_gz(context["project-name"], render("{{ project-name }}.tar.gz", context));
}

if switch_enabled("git-init") || switch_enabled("git-publish") {
  git_init(context["project-name"], "main");
  git_add_all(context["project-name"]);
  git_commit(context["project-name"], "initial commit");
  git_remote_add(context["project-name"], "origin", render("https://github.com/{{ org-solution-name }}/{{ project-name }}.git", context));

  if switch_enabled("git-publish") {
    gh_repo_create(render("{{ org-solution-name }}/{{ project-name }}", context), Private);
    git_push(context["project-name"], "origin", "main");
  }
} else {
  display();

  log(Info, "Copy and paste the following commands to publish your project:");

  display();

  display(render("cd {{ project-name }}", context));
  display("git init -b main");
  display(render("gh repo create {{ org-solution-name }}/{{ project-name }} --private --source=. --remote=origin", context));
  display("git add .");
  display("git commit -m 'initial commit'");
  display("git push -u origin HEAD");
}
