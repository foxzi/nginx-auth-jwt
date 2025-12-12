use Test::Nginx::Socket 'no_plan';

no_root_location();
no_shuffle();

run_tests();

__DATA__

=== access phase
--- http_config
include $TEST_NGINX_CONF_DIR/authorized_server.conf;
--- config
include $TEST_NGINX_CONF_DIR/jwt.conf;
location / {
  auth_jwt "" token=$test1_jwt;
  auth_jwt_key_file $TEST_NGINX_DATA_DIR/jwks.json;
  include $TEST_NGINX_CONF_DIR/authorized_proxy.conf;
}
--- request
GET /
--- response_headers
X-Jwt-Claim-Iss: https://test1.issuer.example.com
X-Jwt-Claim-Sub: test1.identifier
X-Jwt-Claim-Aud: test1.audience.example.com
X-Jwt-Claim-Email: test1@example.com
--- error_code: 200
--- error_log: auth_jwt: ignore phase: PREACCESS
--- log_level: debug

=== preaccess phase
--- http_config
include $TEST_NGINX_CONF_DIR/authorized_server.conf;
--- config
include $TEST_NGINX_CONF_DIR/jwt.conf;
location / {
  auth_jwt "" token=$test1_jwt;
  auth_jwt_key_file $TEST_NGINX_DATA_DIR/jwks.json;
  auth_jwt_phase preaccess;
  include $TEST_NGINX_CONF_DIR/authorized_proxy.conf;
}
--- request
GET /
--- response_headers
X-Jwt-Claim-Iss: https://test1.issuer.example.com
X-Jwt-Claim-Sub: test1.identifier
X-Jwt-Claim-Aud: test1.audience.example.com
X-Jwt-Claim-Email: test1@example.com
--- error_code: 200
--- error_log: auth_jwt: ignore phase: ACCESS
--- log_level: debug

=== server_rewrite phase
--- http_config
include $TEST_NGINX_CONF_DIR/authorized_server.conf;
--- config
include $TEST_NGINX_CONF_DIR/jwt.conf;
auth_jwt "" token=$test1_jwt;
auth_jwt_key_file $TEST_NGINX_DATA_DIR/jwks.json;
auth_jwt_phase server_rewrite;
auth_jwt_allow_failed on;

if ($jwt_status = "ok") {
  set $jwt_valid "yes";
}

location / {
  add_header X-Jwt-Valid $jwt_valid;
  include $TEST_NGINX_CONF_DIR/authorized_proxy.conf;
}
--- request
GET /
--- response_headers
X-Jwt-Valid: yes
X-Jwt-Claim-Iss: https://test1.issuer.example.com
X-Jwt-Claim-Sub: test1.identifier
X-Jwt-Claim-Aud: test1.audience.example.com
X-Jwt-Claim-Email: test1@example.com
--- error_code: 200
--- error_log: auth_jwt: ignore phase: REWRITE
--- log_level: debug

=== server_rewrite phase with invalid token
--- http_config
include $TEST_NGINX_CONF_DIR/authorized_server.conf;
--- config
include $TEST_NGINX_CONF_DIR/jwt.conf;
auth_jwt "" token=$test1_invalid_sig_jwt;
auth_jwt_key_file $TEST_NGINX_DATA_DIR/jwks.json;
auth_jwt_phase server_rewrite;
auth_jwt_allow_failed on;

set $jwt_valid "no";
if ($jwt_status = "ok") {
  set $jwt_valid "yes";
}

location / {
  add_header X-Jwt-Valid $jwt_valid;
  add_header X-Jwt-Status $jwt_status;
  return 200 "ok";
}
--- request
GET /
--- response_headers
X-Jwt-Valid: no
X-Jwt-Status: sig_invalid
--- error_code: 200
--- log_level: debug
