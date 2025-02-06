[0;1;32m●[0m sshd.service - OpenSSH Daemon
     Loaded: loaded (]8;;file://sysrescue/usr/lib/systemd/system/sshd.service/usr/lib/systemd/system/sshd.service]8;;; [0;1;38:5:185mdisabled[0m; preset: [0;1;38:5:185mdisabled[0m)
     Active: [0;1;32mactive (running)[0m since Thu 2025-02-06 15:05:25 UTC; 24ms ago
 Invocation: dca5df2f5be44e429a1e9bb91fa6ccc0
   Main PID: 1751 (sshd)
      Tasks: 1[0;38;5;245m (limit: 18656)[0m
     Memory: 1.1M (peak: 1.5M)
        CPU: 22ms
     CGroup: /system.slice/sshd.service
             └─[0;38;5;245m1751 "sshd: /usr/bin/sshd -D [listener] 0 of 10-100 startups"[0m

Feb 06 15:05:25 sysrescue systemd[1]: Starting OpenSSH Daemon...
Feb 06 15:05:25 sysrescue sshd[1751]: Server listening on 0.0.0.0 port 22.
Feb 06 15:05:25 sysrescue sshd[1751]: Server listening on :: port 22.
Feb 06 15:05:25 sysrescue systemd[1]: Started OpenSSH Daemon.
