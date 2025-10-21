# Zammad LDAP Configuration
# Initialize LDAP integration with Zammad

# Enable LDAP authentication
Setting.set('ldap_auth_method', 'LdapUser')
Setting.set('ldap_active', true)

# Set LDAP server details
Setting.set('ldap_config', {
  'host' => "${ZAMMAD_LDAP_HOST}",
  'port' => ${ZAMMAD_LDAP_PORT},
  'ssl' => ${ZAMMAD_LDAP_SSL},
  'base_dn' => "${ZAMMAD_LDAP_BASE_DN}",
  'bind_dn' => "${ZAMMAD_LDAP_BIND_DN}",
  'bind_password' => "${ZAMMAD_LDAP_BIND_PASSWORD}",
  'filter' => '(objectClass=inetOrgPerson)',
  'attributes' => {
    'login' => 'uid',
    'first_name' => 'givenname',
    'last_name' => 'sn',
    'email' => 'mail'
  }
})

# Create system user for LDAP sync
user = User.find_by(login: 'ldap_sync')
if !user
  User.create!(
    login: 'ldap_sync',
    first_name: 'LDAP',
    last_name: 'Sync',
    email: "ldap_sync@${TRAEFIK_DOMAIN}",
    password: SecureRandom.hex(32),
    active: true,
    roles: [Role.find_by(name: 'Admin'), Role.find_by(name: 'Agent')],
    groups: [Group.find_by(name: 'LDAP')],
    preferences: {
      'locale' => 'en',
      'notification_config' => {
        'create_article' => false
      }
    }
  )
end

# Set up LDAP group
group = Group.find_by(name: 'LDAP')
if !group
  Group.create!(
    name: 'LDAP',
    signature: '',
    follow_up_assignment: true,
    follow_up_creation: true,
    email_address: nil,
    created_by_id: User.find_by(login: 'ldap_sync').id,
    updated_by_id: User.find_by(login: 'ldap_sync').id
  )
end

# Set up SLA policies
Sla.create!(
  name: 'Standard SLA',
  first_response_time: 8.hours,
  update_time: 24.hours,
  solution_time: 72.hours,
  calendar_name: 'Standard',
  created_by_id: User.find_by(login: 'ldap_sync').id,
  updated_by_id: User.find_by(login: 'ldap_sync').id
) if Sla.find_by(name: 'Standard SLA').nil?
