#!/bin/bash

# Backup the override file
cp docker-compose.override.yml docker-compose.override.yml.backup.$(date +%Y%m%d_%H%M%S)

# Create a Python script to clean up override file
cat > clean_override.py << 'EOF'
import yaml

# Load the override file
with open('docker-compose.override.yml', 'r') as file:
    override_data = yaml.safe_load(file)

# Services to remove
services_to_remove = ['realtime', 'vector', 'imgproxy']

# Remove the services if they exist
if 'services' in override_data:
    for service in services_to_remove:
        if service in override_data['services']:
            del override_data['services'][service]
            print(f"Removed override for service: {service}")

# Save the modified file
with open('docker-compose.override.yml', 'w') as file:
    yaml.dump(override_data, file, default_flow_style=False, sort_keys=False)

print("Successfully cleaned override file")
EOF

# Run the Python script
python3 clean_override.py

# Remove the Python script
rm clean_override.py

echo "Override file cleaned successfully!"
