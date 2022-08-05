# Lunar Installer for ComputerCraft

This is a small install utility for ComputerCraft and CC: Tweaked, it allows you to easily install and uninstall packages that implement its `ccpkg.json` format from sources such as GitHub.

## Installing Packages

To install a new package you can run the installer directly from Pastebin: `pastebin run Mt7h3gfz install/uninstall [source] [package] [options]`, replacing the `[source]` with where to fetch your package from (currently only supports `github`), followed by the package name, in this case, using the `owner/repo-name` format.

For options you can add any of the JSON properties, prefixed with `--`, as far you use a dot to separate parts from the config.

In that case, if you want to override a package's default branch to, let's say, a development branch, just add `--source.branch=your-new-branch`

## Creating a new Package

Just add a file called `ccpkg.json` on your project's root directory with details on where the installer should look for your files, and you're done! Simple as that :)

For example, if you host your package on GitHub, you can have the installer fetch your repo during install with the JSON below:

```json
{
  "id": "hello",
  "name": "Hello World",
  "source": {
    "type": "github",
    "repo": "wolfe-labs/CC-Hello",
    "branch": "main"
  },
  "bin": {
    "hello": {
      "path": "src/the-hello-1.lua",
      "text": "Just a hello world"
    },
    "hello-2": "src/the-hello-2.lua"
  }
}
```

What the JSON above gives us:

- A package identifier, in this case "hello", which should be something to uniquely identify your program.
- The name field, which currently has no use
- A "source" definition, that tells the installer to look on GitHub, under the "wolfe-labs/CC-Hello" repository, on the "main" branch.
- Two binaries that will be added to the root directory, and the files they will point to.