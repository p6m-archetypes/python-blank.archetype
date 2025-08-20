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

context += set("project-name", render("{{ prefix-name }}-{{ suffix-name }}", context), #{
  cases: [
    CasedIdentityCasedValue(PROGRAMMING_CASES),
  ],
});

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
