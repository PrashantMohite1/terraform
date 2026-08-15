### `sed` Important Flags

| Flag     | Meaning                     | Example                    | What it does                            |                                      |
| -------- | --------------------------- | -------------------------- | --------------------------------------- | ------------------------------------ |
| `-i`     | Edit file in-place          | `sed -i 's/old/new/' file` | Modifies the actual file                |                                      |
| `-n`     | Suppress automatic printing | `sed -n '5p' file`         | Prints only what you explicitly ask for |                                      |
| `-E`     | Extended regex              | `sed -E 's/foo             | bar/xxx/' file`                         | Enables extended regular expressions |
| `-e`     | Specify expression          | `sed -e 's/a/b/' file`     | Provides a `sed` expression             |                                      |
| `-i.bak` | Edit + create backup        | `sed -i.bak 's/a/b/' file` | Modifies file and creates `file.bak`    |                                      |
| `-r`     | Extended regex              | `sed -r 's/foo             | bar/x/' file`                           | Older alternative to `-E`            |

### `sed` Important Commands

| Command | Meaning    | Example                 | What it does                  |
| ------- | ---------- | ----------------------- | ----------------------------- |
| `s`     | Substitute | `sed 's/foo/bar/' file` | Replace `foo` with `bar`      |
| `d`     | Delete     | `sed '/foo/d' file`     | Delete lines containing `foo` |
| `p`     | Print      | `sed -n '/foo/p' file`  | Print matching lines          |
| `a`     | Append     | `sed '$a\hello' file`   | Add text after selected line  |
| `i`     | Insert     | `sed '1i\hello' file`   | Add text before selected line |
| `q`     | Quit       | `sed '5q' file`         | Stop after line 5             |

### The most important ones to remember

```text
-i    → modify file
-n    → don't print automatically
-E    → extended regex

s     → substitute
d     → delete
p     → print
a     → append
i     → insert
```

For DevOps/Linux work, these are the ones you'll use most frequently.
