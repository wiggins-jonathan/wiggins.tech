---
title: "Use Nix for Shareable Developer Environments"
date: 2024-11-27T12:43:30-07:00
showToC: true
TocOpen: true
---

# What is Nix?
Nix is confusingly both a language & a package manager,
[among other things](https://en.wikipedia.org/wiki/NixOS).

The language & the package manager can work together to create reproducible,
declarative, shareable, & isolated environments for software development.

## Nix develop
The `nix develop` command is a tool in the Nix ecosystem that allows the
creation of development environments defined by a local file called a "flake".

Running this command builds & installs all dependencies defined in the flake
hermetically, meaning that exiting the environment removes the installed
dependencies from the environment.

## Nix flakes
Nix flakes, currently an experimental feature, offers an enhanced way to manage
Nix configurations & dependencies in a declarative fashion.

By using Nix flakes, developers can define reusable configurations, making it
easier to share & maintain complex environments across teams & projects.

### Create `flake.nix`
The basis & entry point for Nix flakes is a text file named `flake.nix` written
in the Nix
[functional language](https://en.wikipedia.org/wiki/Functional_programming).
Nix can quickly create a default flake based on the current packages in the
Nix package repositories:

```sh
$ nix flake init
wrote: /your/current/directory/flake.nix
```

Creating one manually is often more efficient. In theory, the flake.nix file is
simple & only requires two things, `inputs` & `outputs`.

#### Inputs
`inputs` are an attribute set (a.k.a. map, hashmap, dictionary, associative
array, etc.) that defines our source code repositories. This is almost always
going to have a git-style url pointing to the nixpkgs github. Here the
`nixos-unstable` branch of [nixpkgs](https://github.com/nixos/nixpkgs) is
specifically referenced.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };
}
```

#### Outputs
`outputs` is a function that outputs your "derivation". A derivation can be
anything: an executable file, a Dockerfile; or in this case, a developer
environment. This function should take in the `self` parameter & our nixpkgs
input in order to get access to the nix packages hosted on github.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {self, nixpkgs}:
}
```

Because nix is a purely functional language, it is common to assign variables
scoped to our `outputs` function in a `let/in` clause before the function body.

This is useful to specify the system for which our software dependencies should
be built. Here `x86_64-linux` is specified, but will be different for MacOS or
various other systems.
[These will be taken into account later in the article](#dynamic-system-builds).

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {self, nixpkgs}:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
}
```

Now that the system for the dependencies has been defined, `devShells` can be
correctly called with the defined `system`. `mkShell`, similarly, is now defined
for the system & the list of packages to be installed will use the correct
system architecture.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {self, nixpkgs}:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        go
        hugo
      ];
    };
  };
}
```

`shellHook` can be optionally defined to run any shell command. Defining
environment variables or printing important info to the terminal when entering
the environment are common usages:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {self, nixpkgs}:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        go
        hugo
      ];

      shellHook = ''
        export HELPFUL_ENV_VAR="a helpful environment variable"
        echo "Happy hacking!"
        echo "$(go version)"
        echo "$(hugo version)"
      '';

    };
  };
}
```
```sh
$ nix develop
Happy hacking!
go version go1.22.8 linux/amd64
hugo v0.126.1+extended linux/amd64 BuildDate=unknown VendorInfo=nixpkgs
(nix:nix-shell-env) bash-5.2$ echo "$HELPFUL_ENV_VAR"
a helpful environment variable
(nix:nix-shell-env) bash-5.2$
```

### Validate `flake.nix`
In order to validate the syntax & configuration of our `flake.nix` file, Nix
understands common development tools & `flake.nix` needs to be checked
in to a version control system. _*Add Explanation Here.*_
Let's use `git`.
```sh
$ git init
Initialized empty Git repository in /your/current/directory/here.git/
$ git add flake.nix
```

Now check the flake.nix for syntax errors & other problems:
```sh
$ nix flake check
```

### Manage Nix dependencies with flake.lock
Running any `nix` command on `flake.nix` such as `nix flake check` will create
or update a `flake.lock` file that is similar to other languages dependency files
such as `packages.json` in Node for Javascript or `go.sum` for Golang.

This file references the
[sha](https://en.wikipedia.org/wiki/Secure_Hash_Algorithms)
hash of a specific git commit in the nixpkgs repo (or any repo defined in the
inputs) & gives the ability to ensure completely accurate & reproducible builds.

### Dynamic System Builds
Development teams often have a varied number of workstations, & therefore
systems, that need to be taken into account when building or installing
dependencies.

There are numerous ways of doing so.
[flake-utils](https://github.com/numtide/flake-utils), developed by
[numtide](https://numtide.com/), is a common approach. Creating a function
that takes in systems you want to support & loops over them can also be a
more simple method:

```nix
# flake.nix
  outputs = { self, nixpkgs }:
    let
      systems = ["x86_64-linux" "x86_64-darwin"];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in { ...
```

This function, named `forEachSystem`, uses `genAttrs` & loops over the array of
systems to installed for each system listed in the array.

To finish, call the `forEachSystem` function when creating the development
shells:

```nix
    in {
      devShells = forEachSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            go
            hugo
          ];

          shellHook = ''
            export HELPFUL_ENV_VAR="a helpful environment variable"
            echo "Happy hacking!"
            echo "$(go version)"
            echo "$(hugo version)"
          '';
        };
      });
    };
```

## Real World Example
This site itself uses nix flakes in order to create a development environment
that contains [Go](https://go.dev/) & [Hugo](https://gohugo.io/) so that
creating, building, & collaborating on the site is easy.
