# External skills

This repo intentionally does **not** vendor upstream skill repositories.

## NotebookLM

- Upstream: `https://github.com/PleasePrompto/notebooklm-skill`
- Expected location: `~/.jcode/skills/notebooklm`
- Why excluded: keep this repo focused on my wrappers/config and avoid copying third-party source.

### Install manually

```bash
git clone https://github.com/PleasePrompto/notebooklm-skill ~/.jcode/skills/notebooklm
```

### Notes

- After cloning, keep any local data/auth outside git.
- If you later add local wrappers or patches, store only the patch notes or your wrapper files in this repo.
