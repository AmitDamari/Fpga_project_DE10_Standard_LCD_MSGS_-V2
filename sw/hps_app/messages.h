#ifndef MESSAGES_H
#define MESSAGES_H

static const char* MSG_LIST[18][4] = {
    {"System Check:", "All Systems", "Normal", "Status: OK"},
    {"Network:", "Connecting...", "IP: 192.168.1.5", "Signal: Strong"},
    {"Warning!", "Temp High", "Check Fan", "Speed"},
    {"User Mode:", "Admin", "Access Level", "Root"},
    {"FPGA Status:", "Configured", "Running", "GHRD v1.0"},
    {"Memory:", "DDR3: OK", "SD Card: OK", "Usage: 12%"},
    {"Audio:", "Muted", "Volume: 0", "Output: AUX"},
    {"Video:", "HDMI Out", "Res: 1080p", "Active"},
    {"Sensor 1:", "Reading...", "Value: 452", "Stable"},
    {"Sensor 2:", "Reading...", "Value: 881", "Peak"},
    {"Time:", "12:00 PM", "Date:", "01/01/2024"},
    {"Power:", "Battery: 98%", "Charging", "AC Connected"},
    {"Task List:", "1. Main Loop", "2. LCD Upd", "3. Input"},
    {"Error Log:", "None", "Clean Boot", "No Interrupts"},
    {"Ethernet:", "Link Up", "1000 Mbps", "Full Duplex"},
    {"USB Host:", "Detected", "Mouse", "Keyboard"},
    {"LED Status:", "All OFF", "Mode: Eco", "Saving Power"},
    {"Credits:", "Project by", "Contributor", "Outlier AI"}
};

#endif