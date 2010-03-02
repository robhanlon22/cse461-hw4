# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_hw4_session',
  :secret      => 'b4a396f68036d1a12b8cf67cdf0c91b696a8f76fe0aa2bb549c99690e23621d3f60b67ab5963348d2723053b2440c365fb66cc3f0a788ef76224f1d8fa32323d'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
