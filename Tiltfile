#load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://podman', 'podman_build')
load('ext://secret', 'secret_from_dict')
#load('ext://uibutton', 'cmd_button')

allow_k8s_contexts('kubernetes-admin@kubernetes')
default_registry( 'docker.io/ukatru')
# Set up secrets with defaults for development
k8s_yaml(secret_from_dict('tiltfile', inputs = {
  'postgres-password' : os.getenv('POSTGRESQL_PASSWORD', 's3sam3')
}))

# Use Helm to spin up postgres
#helm_resource(
#  name='postgresql',
#  chart='oci://registry-1.docker.io/bitnamicharts/postgresql',
#  flags=[
#      # TODO: 15.x appears to have problems with ephemeral-storage limits that
      # I haven't been able to debug yet
#      '--version=^14.0',
#      '--set=image.tag=16.2.0-debian-12-r8',
#      '--set=global.postgresql.auth.existingSecret=tiltfile'
#  ],
#  labels=['database']
#)

# The Rails app itself is built and served by app.yaml
podman_build('python-tilt', '.', 
  extra_flags=['--file', 'Containerfile.dev'],
)
k8s_yaml('k8s.yaml')
k8s_resource('python-example', 
  labels=['app'],
  port_forwards='8080:8080'
)
