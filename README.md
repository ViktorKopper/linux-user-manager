✍️ Author
Viktor Kopper
---
Sysadmin & Infrastructure Engineer

📈 Why This Project?
---
This project demonstrates:

Real-world Linux system administration automation

Attention to security, input validation, and logging

Modular Bash scripting with UX enhancements

Practical DevOps scripting knowledge

---

**# 🧑‍💻 Linux User Manager**

A robust and extensible Bash script to manage Linux user accounts securely, reliably, and professionally. Designed for system administrators, this script streamlines user creation with built-in validation, logging, and automation-friendly CLI options.

---

**## 📌 Features**

- ✅ **Username validation** (POSIX-compliant, prevents invalid or existing usernames)
- 🔒 **Root permission check** with clear errors
- 👥 **Group assignment** (`--groups`)
- 💬 **User description support** (`--comment`)
- 🐚 **Shell configuration** (`--shell`, defaults to `/bin/bash`)
- 📜 **Structured logging** to `/tmp/user_management_*.log`
- 🖍️ **Color-coded terminal output**
- ⚙️ Optional improvements: `--dry-run`, `--no-password`, `--verbose`, interactive confirmation, semantic color control (see [IMPROVEMENTS_SUMMARY.md](./IMPROVEMENTS_SUMMARY.md))

---

**## 🚀 Usage**

```bash
sudo ./User.sh <username> [--groups group1,group2] [--shell /bin/zsh] [--comment "Some description"]

---

**##📘 Examples**
bash
Kopírovať
Upraviť
# Create basic user with default shell
sudo ./User.sh johndoe

# Create user with additional groups and comment
sudo ./User.sh devuser --groups docker,sudo --comment "DevOps Engineer"

# Specify a custom shell
sudo ./User.sh customuser --shell /bin/zsh
```
---

**##📂 Log Output**
Log files are saved with a timestamp in /tmp, e.g.:

```
/tmp/user_management_20250725_104512.log
Each log includes:
```
Timestamped entries

Log level (INFO, ERROR, WARNING)

Executed commands and outcomes

---

**🔧 Requirements**
Debian-based Linux system (Ubuntu, etc.)

sudo privileges

Bash 4+

---

**##🛡️ Improvements & Extensions**
This script is extensible and production-ready. See IMPROVEMENTS_SUMMARY.md for:

✨ Enhanced color system using semantic mappings

🔁 Dry-run and verbose modes

🔐 Shell and input validation hardening

🧪 Test mode for safe simulations

🚫 Optional password skip mode

📦 Modular structure and logging levels

🧠 Better maintainability and user experience
