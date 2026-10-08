# Neovim config

Works on macOS and Windows. See [cheatsheet.md](cheatsheet.md) for keys and commands.

## Prerequisites

Required:

- Neovim 0.11 or newer
- `git` (plugins are installed by lazy.nvim)
- `ripgrep` (`rg`), used by Telescope live grep and the notes plugin

  ```sh
  brew install ripgrep          # macOS
  winget install BurntSushi.ripgrep.MSVC   # Windows
  ```

Optional:

- `lazygit` for `:LazyGit` (`<leader>gc`)
- `make` and a C compiler to build `telescope-fzf-native` (Telescope still works without it)
- A Nerd Font, so file icons render (see below)

### Nerd Font (optional)

neo-tree, Telescope and Octo use icons from a Nerd Font. Without one, the terminal shows
boxed `?` characters next to files and folders and in the git status column. This is a
font issue only, nothing is broken.

#### macOS

```sh
brew install --cask font-jetbrains-mono-nerd-font
```

Then set it in your terminal:

- **Terminal.app:** Settings → Profiles → pick your profile → Text → Font → Change… →
  choose `JetBrainsMono Nerd Font`.
- **iTerm2:** Settings → Profiles → Text → Font.
- **Other terminals (WezTerm, Alacritty, kitty…):** set the font family in their config.

Restart the terminal afterwards.

#### Windows

```powershell
winget install DEVCOM.JetBrainsMonoNerdFont
```

If winget cannot find that id, run `winget search "Nerd Font"`, or download a font from
[nerdfonts.com](https://www.nerdfonts.com/font-downloads), unzip it, select the `.ttf`
files, right-click and choose **Install for all users**.

Then set it in Windows Terminal: Settings → Profiles → Defaults (or your profile) →
Appearance → Font face → `JetBrainsMono Nerd Font`. Or in `settings.json`:

```json
"profiles": {
  "defaults": {
    "font": { "face": "JetBrainsMono Nerd Font" }
  }
}
```

Restart the terminal afterwards. The face name is whatever the font manager shows,
usually ending in `Nerd Font` or `NF`.

Any Nerd Font works, JetBrainsMono is only a suggestion.
