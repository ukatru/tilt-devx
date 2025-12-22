#load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://podman', 'podman_build')
load('ext://secret', 'secret_from_dict')
load('ext://dotenv', 'dotenv')
#load('ext://uibutton', 'cmd_button')

# Load environment variables from .env file
dotenv('.env')

# ========== CONFIGURABLE VARIABLES ==========
# These can be set in .env file or will use defaults
APP_NAME = os.getenv('APP_NAME', 'python-example')
CONTAINER_FILE = os.getenv('CONTAINER_FILE', 'Dockerfile.simple')
K8S_YAML_FILE = os.getenv('K8S_YAML_FILE', 'k8s.yaml')
K8S_NAMESPACE = os.getenv('K8S_NAMESPACE', 'default')
PORT_FORWARD = os.getenv('PORT_FORWARD', '8081:8787')
CONTAINER_PORT = os.getenv('CONTAINER_PORT', '8080')
REPLICAS = os.getenv('REPLICAS', '1')
NODE_SELECTOR = os.getenv('NODE_SELECTOR', '')
IMAGE_PULL_SECRET = os.getenv('IMAGE_PULL_SECRET', '')
DOCKER_REGISTRY = os.getenv('DOCKER_REGISTRY', 'docker.io/ukatru')
AWS_REGION = os.getenv('AWS_REGION', 'us-west-2')
AWS_ACCOUNT_ID = os.getenv('AWS_ACCOUNT_ID', '')
USE_ECR = os.getenv('USE_ECR', 'false').lower() == 'true'
CREATE_SECRETS = os.getenv('CREATE_SECRETS', 'true').lower() == 'true'

# Opinionated: secret name is always APP_NAME-secrets
SECRET_NAME = APP_NAME + '-secret'

print('APP_NAME: ' + APP_NAME)
print('SECRET_NAME: ' + SECRET_NAME)
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

# ========== DYNAMIC SECRETS ==========
# Automatically collect all env vars that start with SECRET_
secret_inputs = {}
for key, value in os.environ.items():
  if key.startswith('SECRET_'):
    # Remove SECRET_ prefix and convert to lowercase with hyphens
    secret_key = key[7:].lower().replace('_', '-')
    secret_inputs[secret_key] = value
    print('Adding secret: {} (from {})'.format(secret_key, key))

# Add default postgres password if not provided
if 'postgres-password' not in secret_inputs:
  secret_inputs['postgres-password'] = os.getenv('POSTGRESQL_PASSWORD', 'test')
  print('Adding secret: postgres-password')

print('Total secrets to create: {}'.format(len(secret_inputs)))
print('Secret keys: {}'.format(', '.join(secret_inputs.keys())))

# Only create secrets if CREATE_SECRETS is true and we have secrets to create
if CREATE_SECRETS and len(secret_inputs) > 0:
  k8s_yaml(secret_from_dict(SECRET_NAME, inputs=secret_inputs))
  print('Created secret: ' + SECRET_NAME)
else:
  print('Skipping secret creation (CREATE_SECRETS={}, secret_count={})'.format(CREATE_SECRETS, len(secret_inputs)))

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
