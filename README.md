# Takamaru

Messages gem for Sasori microservices.

## Initial config

**:warning: Please, run the following steps the first time you pull this repository.**

- This workspace has **extension reccomendations** for Visual Studio Code; please, install all of them at the first run.
- Also, open the folder `/workspace/takamaru` at the first run.
- Then setup git flow with the following command: `git flow init -f -d --bugfix bugfix/ --feature feature/ --hotfix hotfix/ --release release/ --support support/ --tag ''`.
- Tell `git` where to find the project shared hooks: `git config core.hooksPath .githooks`.
- Run `bundle` to install all the gems.

## Code Style

[Rubocop](https://github.com/rubocop/rubocop) gem is enabled by default in `devcontainer` and will automatically format
files on save and check all the project before commit.

[Ruby Style Guide](https://github.com/Shopify/ruby-style-guide) gem is the source for our style guide. We changed just
a little of config in the `.rubocop.yml` file.

## Code quality

To run all the quality checks together use the this command:

```console
$ rails code_quality:check
```

[RubyCritic](https://github.com/whitesmith/rubycritic) gem should be used from `cli` to generate `html` report in
`/tmp/rubycritic`. Simply run the command `rubycritic` from workspace root path.

[Bundler audit](https://github.com/rubysec/bundler-audit) gem should be used from `cli` to generate a `json` report in
`/tmp/bundler-audit.json`. Simply run the command `bundle-audit` from workspace root path.
