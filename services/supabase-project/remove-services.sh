#!/bin/bash

# Create a backup
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

# Create a Python script to remove services from docker-compose.yml
cat > remove_services.py << 'EOF'
import yaml
import sys

# Load the docker-compose file
with open('docker-compose.yml', 'r') as file:
    compose_data = yaml.safe_load(file)

# Services to remove
services_to_remove = ['realtime', 'vector', 'imgproxy']

# Remove the services
for service in services_to_remove:
    if service in compose_data['services']:
        del compose_data['services'][service]
        print(f"Removed service: {service}")

# Remove dependencies on these services from other services
for service_name, service_config in compose_data['services'].items():
    if 'depends_on' in service_config:
        # Check if depends_on is a dict or list
        if isinstance(service_config['depends_on'], dict):
            for dep_service in services_to_remove:
                if dep_service in service_config['depends_on']:
                    del service_config['depends_on'][dep_service]
                    print(f"Removed dependency on {dep_service} from {service_name}")
        elif isinstance(service_config['depends_on'], list):
            service_config['depends_on'] = [dep for dep in service_config['depends_on'] 
                                           if dep not in services_to_remove]
            
# Special handling for storage service - remove imgproxy dependency
if 'storage' in compose_data['services']:
    if 'depends_on' in compose_data['services']['storage']:
        if 'imgproxy' in compose_data['services']['storage']['depends_on']:
            del compose_data['services']['storage']['depends_on']['imgproxy']
            
    # Remove imgproxy URL from environment
    if 'environment' in compose_data['services']['storage']:
        env = compose_data['services']['storage']['environment']
        if isinstance(env, dict) and 'IMGPROXY_URL' in env:
            del env['IMGPROXY_URL']
        elif isinstance(env, list):
            compose_data['services']['storage']['environment'] = [e for e in env 
                                                                 if not e.startswith('IMGPROXY_URL=')]

# Fix db service - remove vector dependency
if 'db' in compose_data['services']:
    if 'depends_on' in compose_data['services']['db']:
        if 'vector' in compose_data['services']['db']['depends_on']:
            del compose_data['services']['db']['depends_on']['vector']
            
    # Also remove realtime.sql volume if it exists
    if 'volumes' in compose_data['services']['db']:
        compose_data['services']['db']['volumes'] = [v for v in compose_data['services']['db']['volumes'] 
                                                    if 'realtime.sql' not in v]

# Save the modified file
with open('docker-compose.yml', 'w') as file:
    yaml.dump(compose_data, file, default_flow_style=False, sort_keys=False)

print("Successfully removed services and updated dependencies")
EOF

# Run the Python script
python3 remove_services.py

# Remove the Python script
rm remove_services.py

echo "Services removed successfully!"
