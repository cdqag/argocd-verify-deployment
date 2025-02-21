load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"
load "test_helper/bats-mock/stub"
load "test_helper/common"

setup() {
	common_setup
}

teardown() {
	common_teardown

	unstub argocd || true
}

@test "should fail if app name is not provided" {
	run ./src/verify.sh

	assert_failure 11
	assert_output "[ERROR] Invalid input: app_name cannot be an empty string"
}

@test "should fail if app version is not provided" {
	run ./src/verify.sh -n my-app

	assert_failure 12
	assert_output "[ERROR] Invalid input: app_version cannot be an empty string"
}

@test "should fail if docker org is not provided" {
	run ./src/verify.sh -n my-app -v 1.2.3

	assert_failure 13
	assert_output "[ERROR] Invalid input: docker_org cannot be an empty string"
}

@test "should skip verification if images list is null" {
	stub argocd "app get my-app \* : cat '$DIR/test/fixtures/images-null.json'"

	run ./src/verify.sh -n my-app -v 1.2.3 -o my-org

	assert_success
	assert_output "[NOTICE] ArgoCD App Deployment Verification Skipped: Deployed ArgoCD App 'my-app' has no images running. This probably means that no pods are running. Skipping verification."
}

@test "should skip verification if images list is empty" {
	stub argocd "app get my-app \* : cat '$DIR/test/fixtures/images-empty.json'"

	run ./src/verify.sh -n my-app -v 1.2.3 -o my-org

	assert_success
	assert_output "[NOTICE] ArgoCD App Deployment Verification Skipped: Deployed ArgoCD App 'my-app' has no images running. This probably means that no pods are running. Skipping verification."
}

@test "should fail verification" {
	stub argocd "app get my-app \* : cat '$DIR/test/fixtures/images-populated-invalid.json'"

	run ./src/verify.sh -n my-app -v 1.2.3 -o my-org

	assert_failure 14
	assert_output "[ERROR] Deployed ArgoCD App Verification Failed: Deployed ArgoCD App 'my-app' has not passed the verification. Neither running pod is using the image with tag '1.2.3'. Found images: [\"other-org/other-app:1.2.3\",\"my-org/my-app:1.2.2\"]"
}

@test "should pass verification" {
	stub argocd "app get my-app \* : cat '$DIR/test/fixtures/images-populated-valid.json'"

	run ./src/verify.sh -n my-app -v 1.2.3 -o my-org

	assert_success
	assert_output "[INFO] Everything looks fine!"
}
