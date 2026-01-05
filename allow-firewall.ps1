
# Run this script as Administrator to allow port 4000 through firewall
netsh advfirewall firewall add rule name="WattBuddy Server" dir=in action=allow protocol=tcp localport=4000 description="Allow WattBuddy backend server"
netsh advfirewall firewall add rule name="WattBuddy Server" dir=out action=allow protocol=tcp localport=4000 description="Allow WattBuddy backend server"
Write-Host "Firewall rules added successfully!"
