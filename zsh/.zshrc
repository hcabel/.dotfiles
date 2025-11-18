
# # The next line updates PATH for the Google Cloud SDK.
# if [ -f '/home/hcabel/Downloads/google-cloud-sdk/path.bash.inc' ]; then . '/home/hcabel/Downloads/google-cloud-sdk/path.bash.inc'; fi

#
# # The next line enables shell command completion for gcloud.
# if [ -f '/home/hcabel/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . '/home/hcabel/Downloads/google-cloud-sdk/completion.bash.inc'; fi

# portfwd() {
#     cd ~/aive/;
#     sudo -E kubefwd svc -d staging;
# }
#
# aive() {
#     cd ~/aive/;
#     aivebuild ${1:-};
#     if [ "$1" == "graphql" ]; then
#         return;
#     fi
#     aiverun ${1:-};
# }
# aivemake() { aive ${1:-}; }
#
# aivebuild() {
#     cd ~/aive/;
#     make build pkg=$1 ${2:-};
# }
#
# aiverun() {
#     cd ~/aive/;
#     if [ "$1" == "platform-app" ]; then
#         make serve pkg=platform-app ${2:-};
#     else
#         source bin/$1.env && bin/$1 ${2:-};
#     fi
# }
# aivestart() { aiverun ${1:-}; }
#
# aivetest() {
#     cd ~/aive/;
#     make test pkg=$1 ${2:-};
# }
#
# alias lg='lazygit'
#
# aivepipeline()
# {
#     cd ~/aive/;
#     tools/list-changed-packages.py origin/main | jq '.[]' -r | sort | while IFS= read -r pkg
# do
#     echo " "
#     echo "*** ${pkg} ***"
#     if [[ "${pkg}" != *\/* ]]; then
#         make build-ci pkg="${pkg}"
#     fi
#     make test-ci pkg="${pkg}"
# done
# }
