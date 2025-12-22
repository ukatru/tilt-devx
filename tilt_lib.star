# tilt_lib.star - Reusable Tilt helper functions

load('ext://secret', 'secret_from_dict')

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

def get_config(env_file='.env'):
  """Load configuration from .env file with defaults"""
  env_vars = load_env_file(env_file)
  
  def get_env(key, default=''):
    return env_vars.get(key, os.getenv(key, default))
  
  config = {
    'APP_NAME': get_env('APP_NAME', 'python-example'),
    'CONTAINER_FILE': get_env('CONTAINER_FILE', 'Dockerfile'),
    'K8S_YAML_FILE': get_env('K8S_YAML_FILE', 'k8s.yaml'),
    'K8S_NAMESPACE': get_env('K8S_NAMESPACE', 'default'),
    'PORT_FORWARD': get_env('PORT_FORWARD', '8080:8787'),
    'CONTAINER_PORT': get_env('CONTAINER_PORT', '8080'),
    'REPLICAS': get_env('REPLICAS', '1'),
    'NODE_SELECTOR': get_env('NODE_SELECTOR', ''),
    'IMAGE_PULL_SECRET': get_env('IMAGE_PULL_SECRET', ''),
    'DOCKER_REGISTRY': get_env('DOCKER_REGISTRY', 'docker.io/ukatru'),
    'AWS_REGION': get_env('AWS_REGION', 'us-west-2'),
    'AWS_ACCOUNT_ID': get_env('AWS_ACCOUNT_ID', ''),
    'USE_ECR': get_env('USE_ECR', 'false').lower() == 'true',
    'CREATE_SECRETS': get_env('CREATE_SECRETS', 'true').lower() == 'true',
  }
  
  # Opinionated names
  config['SECRET_NAME'] = config['APP_NAME'] + '-secret'
  config['COMMON_SECRET_NAME'] = 'common-secret'
  config['CONFIGMAP_NAME'] = config['APP_NAME'] + '-config'
  config['env_vars'] = env_vars
  
  return config

def setup_ecr_login(config):
  """Setup ECR login if enabled"""
  if config['USE_ECR'] and config['AWS_ACCOUNT_ID']:
    ecr_registry = '{}.dkr.ecr.{}.amazonaws.com'.format(
      config['AWS_ACCOUNT_ID'], 
      config['AWS_REGION']
    )
    local_resource(
      'ecr-login',
      'aws ecr get-login-password --region {} | podman login --username AWS --password-stdin {}'.format(
        config['AWS_REGION'], 
        ecr_registry
      ),
      labels=['setup']
    )
    return ecr_registry
  return config['DOCKER_REGISTRY']

def create_common_secrets(config):
  """Create common secrets from .env.common file"""
  common_env_vars = load_env_file('.env.common')
  if len(common_env_vars) > 0:
    print('Creating common-secret from .env.common')
    print('Common secret keys: {}'.format(', '.join(common_env_vars.keys())))
    k8s_yaml(secret_from_dict(config['COMMON_SECRET_NAME'], inputs=common_env_vars))
    print('Created secret: ' + config['COMMON_SECRET_NAME'])
  else:
    print('No .env.common file found or empty - skipping common-secret creation')

def create_app_secrets(config):
  """Create app-specific secrets from SECRET_ env vars"""
  secret_inputs = {}
  
  # Collect from os.environ
  for key, value in os.environ.items():
    if key.startswith('SECRET_'):
      secret_key = key[7:].lower().replace('_', '-')
      secret_inputs[secret_key] = value
      print('Adding secret: {} (from {})'.format(secret_key, key))
  
  # Collect from .env file
  for key, value in config['env_vars'].items():
    if key.startswith('SECRET_'):
      secret_key = key[7:].lower().replace('_', '-')
      if secret_key not in secret_inputs:
        secret_inputs[secret_key] = value
        print('Adding secret: {} (from .env)'.format(secret_key))
  
  # Add default postgres password
  if 'postgres-password' not in secret_inputs:
    secret_inputs['postgres-password'] = config['env_vars'].get('POSTGRESQL_PASSWORD', 'test')
    print('Adding secret: postgres-password')
  
  print('Total app secrets to create: {}'.format(len(secret_inputs)))
  print('App secret keys: {}'.format(', '.join(secret_inputs.keys())))
  
  if config['CREATE_SECRETS'] and len(secret_inputs) > 0:
    k8s_yaml(secret_from_dict(config['SECRET_NAME'], inputs=secret_inputs))
    print('Created secret: ' + config['SECRET_NAME'])
  else:
    print('Skipping app secret creation')

def create_configmap(config):
  """Create ConfigMap from config files if they exist"""
  config_files = ['appsettings.json', 'config.json', 'config.yaml', 'config.yml']
  configmap_data = {}
  
  for config_file in config_files:
    if os.path.exists(config_file):
      print('Found config file: {}'.format(config_file))
      configmap_data[config_file] = read_file(config_file)
  
  if len(configmap_data) > 0:
    configmap_yaml = '''apiVersion: v1
kind: ConfigMap
metadata:
  name: {name}
data:
'''.format(name=config['CONFIGMAP_NAME'])
    
    for filename, content in configmap_data.items():
      lines = str(content).split('\n')
      indented_content = '\n    '.join(lines)
      configmap_yaml += '  {}: |\n    {}\n'.format(filename, indented_content)
    
    k8s_yaml(blob(configmap_yaml))
    print('Created ConfigMap: {} with files: {}'.format(
      config['CONFIGMAP_NAME'], 
      ', '.join(configmap_data.keys())
    ))
    return configmap_data
  else:
    print('No config files found - skipping ConfigMap creation')
    return {}

def render_k8s_yaml(config, has_configmap):
  """Render k8s.yaml template with config values"""
  def render_template(template_content, variables):
    result = template_content
    for key, value in variables.items():
      placeholder = '{{' + key + '}}'
      result = result.replace(placeholder, str(value))
    return result
  
  k8s_template = str(read_file(config['K8S_YAML_FILE']))
  
  template_vars = {
    'APP_NAME': config['APP_NAME'],
    'SECRET_NAME': config['SECRET_NAME'],
    'NAMESPACE': config['K8S_NAMESPACE'],
    'CONTAINER_PORT': config['CONTAINER_PORT'],
    'REPLICAS': config['REPLICAS'],
  }
  
  # Optional node selector
  if config['NODE_SELECTOR']:
    template_vars['NODE_SELECTOR'] = '''
      nodeSelector:
        kubernetes.io/hostname: {}
'''.format(config['NODE_SELECTOR'])
  else:
    template_vars['NODE_SELECTOR'] = ''
  
  # Optional image pull secret
  if config['IMAGE_PULL_SECRET']:
    template_vars['IMAGE_PULL_SECRETS'] = '''
      imagePullSecrets:
      - name: {}
'''.format(config['IMAGE_PULL_SECRET'])
  else:
    template_vars['IMAGE_PULL_SECRETS'] = ''
  
  # Optional ConfigMap volume
  if has_configmap:
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
'''.format(config['APP_NAME'])
  else:
    template_vars['CONFIGMAP_VOLUME'] = ''
  
  rendered_yaml = render_template(k8s_template, template_vars)
  print('Rendered k8s.yaml with APP_NAME: {}'.format(config['APP_NAME']))
  return rendered_yaml
