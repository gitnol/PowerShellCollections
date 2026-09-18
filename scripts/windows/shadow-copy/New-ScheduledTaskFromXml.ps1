schtasks /create /tn "Snapshot_C_Täglich" /xml "Snapshot_C_Täglich.xml" /f
schtasks /create /tn "Wiederherstellungspunkt_C_Täglich" /xml "Wiederherstellungspunkt_C_Täglich.xml" /f

# vssadmin list shadowstorage
# vssadmin list shadows
