#load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://podman', 'podman_build')
load('ext://secret', 'secret_from_dict')
#load('ext://uibutton', 'cmd_button')

# Login to ECR
local_resource(
  'ecr-login',
  'aws ecr get-login-password --region us-west-2 | podman login --username AWS --password-stdin 2317647434.dkr.ecr.us-west-2.amazonaws.com',
  labels=['setup']
)

allow_k8s_contexts('kubernetes-admin@kubernetes')
#default_registry( 'docker.io/ukatru')
default_registry(
  '065306945494.dkr.ecr.us-west-2.amazonaws.com',
  single_name='devlopment/poc')
# Set up secrets with defaults for development
k8s_yaml(secret_from_dict('tiltfile', inputs = {
  'postgres-password' : os.getenv('POSTGRESQL_PASSWORD', 'test')
}))

podman_build('python-tilt', '.', 
  extra_flags=['--file', 'Containerfile.dev'],
)
k8s_yaml('k8s.yaml')
k8s_resource('python-example', 
  labels=['app'],
  port_forwards='8080:8080',
  trigger_mode=TRIGGER_MODE_MANUAL
)
