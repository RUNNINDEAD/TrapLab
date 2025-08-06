# TrapLab

> A modular trap-based logging and monitoring tool for SSH, Ping, and HTTP traffic.

TrapLab is a Bash-based monitoring tool designed to help detect suspicious activity on a Linux system by tracking SSH login attempts, ICMP pings, and HTTP requests. It's great for students, SOC analysts, and cybersecurity hobbyists looking to learn network behavior monitoring in a simple way.

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/RUNNINDEAD/TrapLab.git
cd TrapLab
```

### 2. Make the Script Executable

```bash
chmod +x traplab.sh
```

### 3. Run the Script

```bash
./traplab.sh
```

You’ll be prompted to select which monitoring mode to run (SSH, Ping, HTTP, or All). Logs will be created in the `logs/` directory.

---

## ⚠️ If You Get: `cannot execute: required file not found`

This usually happens when Bash scripts are created or edited on Windows (which uses CRLF line endings).

### ✅ Option 1: Use `dos2unix` (Recommended)

Install it:

**Debian/Ubuntu:**
```bash
sudo apt update && sudo apt install dos2unix
```

**Fedora:**
```bash
sudo dnf install dos2unix
```

Then convert the file:

```bash
dos2unix traplab.sh
chmod +x traplab.sh
./traplab.sh
```

### ✅ Option 2: Use `sed` (Without Installing Anything)

```bash
sed -i 's/\r$//' traplab.sh
chmod +x traplab.sh
./traplab.sh
```

---

## 📁 Log Files

TrapLab saves logs in the `./logs` directory with timestamps:

- `ssh_monitor_YYYYMMDD_HHMMSS.log`
- `ping_monitor_YYYYMMDD_HHMMSS.log`
- `http_monitor_YYYYMMDD_HHMMSS.log`

Each file logs events like failed login attempts, pings, and HTTP connections depending on which monitor is activated.

---

## 🛡️ Use Responsibly

TrapLab is intended for **educational** and **defensive security** purposes only.

Do **NOT** use it on machines or networks you do not own or explicitly have permission to monitor. Always follow ethical and legal guidelines.

---

## 📌 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

© 2025 — Designed by **RUNNINDEAD**  
#StayCuriousStaySharp #RUNNINDEAD #CyberDefense #InfoSec #TrapLab
