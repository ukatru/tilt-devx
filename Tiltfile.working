#load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://podman', 'podman_build')
load('ext://secret', 'secret_from_dict')
#load('ext://uibutton', 'cmd_button')

# ========== MANUAL .ENV PARSING ==========
# More reliable than dotenv() extension
def load_env_file(filepath):
  """Parse .env file and return dict of key-value pairs"""
  env_vars = {}
  if os.path.exists(filepath):
    content = str(read_file(filepath))
    for line in content.split('\n'):
      line = line.strip()
      # Skip comments and empty lines
      if line and not line.startswith('#'):
        if '=' in line:
          key, value = line.split('=', 1)
          env_vars[key.strip()] = value.strip()
  return env_vars

# Load .env file
env_vars = load_env_file('.env')

# Helper function to get env var with fallback
def get_env(key, default=''):
  return env_vars.get(key, os.getenv(key, default))

# ========== CONFIGURABLE VARIABLES ==========
# These can be set in .env file or will use defaults
APP_NAME = get_env('APP_NAME', 'python-example')
CONTAINER_FILE = get_env('CONTAINER_FILE', 'Dockerfile')
K8S_YAML_FILE = get_env('K8S_YAML_FILE', 'k8s.yaml')
K8S_NAMESPACE = get_env('K8S_NAMESPACE', 'default')
PORT_FORWARD = get_env('PORT_FORWARD', '8080:8787')
CONTAINER_PORT = get_env('CONTAINER_PORT', '8080')
REPLICAS = get_env('REPLICAS', '1')
NODE_SELECTOR = get_env('NODE_SELECTOR', '')
IMAGE_PULL_SECRET = get_env('IMAGE_PULL_SECRET', '')
DOCKER_REGISTRY = get_env('DOCKER_REGISTRY', 'docker.io/ukatru')
AWS_REGION = get_env('AWS_REGION', 'us-west-2')
AWS_ACCOUNT_ID = get_env('AWS_ACCOUNT_ID', '')
USE_ECR = get_env('USE_ECR', 'false').lower() == 'true'
CREATE_SECRETS = get_env('CREATE_SECRETS', 'true').lower() == 'true'

# Opinionated: secret names
SECRET_NAME = APP_NAME + '-secret'
COMMON_SECRET_NAME = 'common-secret'  # Always available, optional

print('APP_NAME: ' + APP_NAME)
print('SECRET_NAME: ' + SECRET_NAME)
print('COMMON_SECRET_NAME: ' + COMMON_SECRET_NAME + ' (optional)')
print('PORT_FORWARD: ' + PORT_FORWARD)
print('CONTAINER_PORT: ' + CONTAINER_PORT)
print('CREATE_SECRETS: ' + str(CREATE_SECRETS))

# ========== ECR LOGIN (if enabled) ==========
if USE_ECR and AWS_ACCOUNT_ID:
  ecr_registry = '{}.dkr.ecr.{}.amazonaws.com'.format(AWS_ACCOUNT_ID, AWS_REGION)
  local_resource(
    'ecr-login',
    'aws ecr get-login-password --region {} | podman login --username AWS --password-stdin {}'.format(AWS_REGION, ecr_registry),
    labels=['setup']
  )
  DOCKER_REGISTRY = ecr_registry

# ========== KUBERNETES CONTEXT ==========
allow_k8s_contexts('kubernetes-admin@kubernetes')
default_registry(DOCKER_REGISTRY)

# ========== COMMON SECRETS (from .env.common) ==========
# Load common secrets that are shared across all apps
common_env_vars = load_env_file('.env.common')
if len(common_env_vars) > 0:
  print('Creating common-secret from .env.common')
  print('Common secret keys: {}'.format(', '.join(common_env_vars.keys())))
  k8s_yaml(secret_from_dict(COMMON_SECRET_NAME, inputs=common_env_vars))
  print('Created secret: ' + COMMON_SECRET_NAME)
else:
  print('No .env.common file found or empty - skipping common-secret creation')

# ========== APP-SPECIFIC SECRETS ==========
# Automatically collect all env vars that start with SECRET_
secret_inputs = {}
for key, value in os.environ.items():
  if key.startswith('SECRET_'):
    # Remove SECRET_ prefix and convert to lowercase with hyphens
    secret_key = key[7:].lower().replace('_', '-')
    secret_inputs[secret_key] = value
    print('Adding secret: {} (from {})'.format(secret_key, key))

# Also check .env file for SECRET_ variables
for key, value in env_vars.items():
  if key.startswith('SECRET_'):
    secret_key = key[7:].lower().replace('_', '-')
    if secret_key not in secret_inputs:  # Don't override env vars
      secret_inputs[secret_key] = value
      print('Adding secret: {} (from .env)'.format(secret_key))

# Add default postgres password if not provided
if 'postgres-password' not in secret_inputs:
  postgres_pwd = get_env('POSTGRESQL_PASSWORD', 'test')
  secret_inputs['postgres-password'] = postgres_pwd
  print('Adding secret: postgres-password')

print('Total app secrets to create: {}'.format(len(secret_inputs)))
print('App secret keys: {}'.format(', '.join(secret_inputs.keys())))

# Only create secrets if CREATE_SECRETS is true and we have secrets to create
if CREATE_SECRETS and len(secret_inputs) > 0:
  k8s_yaml(secret_from_dict(SECRET_NAME, inputs=secret_inputs))
  print('Created secret: ' + SECRET_NAME)
else:
  print('Skipping app secret creation (CREATE_SECRETS={}, secret_count={})'.format(CREATE_SECRETS, len(secret_inputs)))

# ========== CONFIGMAPS (from config files) ==========
# Automatically create ConfigMaps from common config files if they exist
config_files = ['appsettings.json', 'config.json', 'config.yaml', 'config.yml']
configmap_name = APP_NAME + '-config'
configmap_data = {}

for config_file in config_files:
  if os.path.exists(config_file):
    print('Found config file: {}'.format(config_file))
    configmap_data[config_file] = read_file(config_file)

if len(configmap_data) > 0:
  # Create ConfigMap YAML
  configmap_yaml = '''apiVersion: v1
kind: ConfigMap
metadata:
  name: {name}
data:
'''.format(name=configmap_name)
  
  for filename, content in configmap_data.items():
    # Indent the content properly - each line needs 4 spaces for YAML literal block
    lines = str(content).split('\n')
    indented_content = '\n    '.join(lines)
    configmap_yaml += '  {}: |\n    {}\n'.format(filename, indented_content)
  
  k8s_yaml(blob(configmap_yaml))
  print('Created ConfigMap: {} with files: {}'.format(configmap_name, ', '.join(configmap_data.keys())))
else:
  print('No config files found - skipping ConfigMap creation')

# ========== RENDER K8S YAML TEMPLATE ==========
def render_template(template_content, variables):
  """Replace template variables with actual values"""
  result = template_content
  for key, value in variables.items():
    placeholder = '{{' + key + '}}'
    result = result.replace(placeholder, str(value))
  return result

# Read the k8s.yaml template
k8s_template = str(read_file(K8S_YAML_FILE))

# Define template variables
template_vars = {
  'APP_NAME': APP_NAME,
  'SECRET_NAME': SECRET_NAME,
  'NAMESPACE': K8S_NAMESPACE,
  'CONTAINER_PORT': CONTAINER_PORT,
  'REPLICAS': REPLICAS,
}

# Add optional node selector
if NODE_SELECTOR:
  template_vars['NODE_SELECTOR'] = '''
      nodeSelector:
        kubernetes.io/hostname: {}
'''.format(NODE_SELECTOR)
else:
  template_vars['NODE_SELECTOR'] = ''

# Add optional image pull secret
if IMAGE_PULL_SECRET:
  template_vars['IMAGE_PULL_SECRETS'] = '''
      imagePullSecrets:
      - name: {}
'''.format(IMAGE_PULL_SECRET)
else:
  template_vars['IMAGE_PULL_SECRETS'] = ''

# Add optional ConfigMap volume mount
if len(configmap_data) > 0:
  template_vars['CONFIGMAP_VOLUME'] = '''
        volumeMounts:
        - name: config
          mountPath: /configs
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: {}-config
          optional: true
'''.format(APP_NAME)
else:
  template_vars['CONFIGMAP_VOLUME'] = ''

# Render the template
rendered_yaml = render_template(k8s_template, template_vars)
print('Rendered k8s.yaml with APP_NAME: {}'.format(APP_NAME))

# ========== BUILD AND DEPLOY ==========
podman_build(APP_NAME, '.', 
  extra_flags=['--file', CONTAINER_FILE],
)

# Use the rendered YAML
k8s_yaml(blob(rendered_yaml))

k8s_resource(APP_NAME, 
  labels=['app'],
  port_forwards=PORT_FORWARD,
  trigger_mode=TRIGGER_MODE_MANUAL
)
