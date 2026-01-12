if status is-interactive
    if test -f '/home/hcabel/google-cloud-sdk/path.fish.inc'
        source '/home/hcabel/google-cloud-sdk/path.fish.inc'
    end

    if test -f '/home/hcabel/google-cloud-sdk/completion.fish.inc'
        source '/home/hcabel/google-cloud-sdk/completion.fish.inc'
    end
end

function portfwd
    sudo -E CLOUDSDK_CONFIG=$HOME/.config/gcloud kubefwd -A -d staging -b --kubeconfig=$HOME/.kube/config
end

function autofwd
    sudo -E ~/autofwd.bash
end

function aive
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aive <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    aivebuild $pkg
    set build_status $status
    if test $build_status -ne 0
        echo "Build failed for package $pkg"
        notify-send "Build failed: '$pkg'"
        return $build_status
    end
    if test $pkg = "graphql"
        return
    end
    aiverun $pkg $args
end
function aivemake
    aive $argv
end

function aivebuild
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aivebuild <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    make build pkg=$pkg $args
end

function aiverun
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aiverun <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    if string match "*-app" $pkg
        make serve pkg=$pkg $args
    else if string match "analyser-*" $pkg
        bin/$pkg $args
    else
        source bin/$pkg.env; and bin/$pkg $args
    end
end
function aivestart
    aiverun $argv
end

function aivetest
    cd ~/aive/;
    if test (count $argv) -eq 0
        echo "Usage: aivetest <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    make test pkg=$pkg $args
end

function aivepipeline
    cd ~/aive/;
    set changed_pkgs (tools/list-changed-packages.py origin/main | jq '.[]' -r | sort)
    for pkg in $changed_pkgs
        echo " "
        echo " "
        set pkg_len (string length $pkg)
        set limiter_str ""
        for i in (seq $pkg_len)
            set limiter_str "$limiter_str-"
        end
        echo " $limiter_str "
        echo " $pkg "
        echo " $limiter_str "
        set rebuild_required (string match -q '*/*' $pkg)
        if test $rebuild_required;
            make build-ci pkg=$pkg
        end
        make test-ci pkg=$pkg
    end
end

function kubediff
    cd ~/stack/;
    if test (count $argv) -gt 0
        set target $argv[1]
    else
        set target "staging-main"
    end

    kubectl diff -k k8s/$target/
end

function kubeapply
    cd ~/stack/;
    if test (count $argv) -gt 0
        set target $argv[1]
    else
        set target "staging-main"
    end

    kubectl apply -k k8s/$target/ | grep -v unchanged
end

function kconfig -d "fetch configMap for a given service in current context via kubectl"
    kubectl get configMap/$argv -o json | jq '.data.LOGGER_FORMAT = "text" | .data | to_entries[] | "export "+.key+"=\""+.value+"\""' -r
end

function kuberestartedpods
    kubectl get pods | grep -e "\s[0-9]\{1,2\}\(m\|s\)\$"
end

function aivedeploy
    cd ~/aive/;
    set ticket-tag $argv[1]
    set ticket-tag $argv[1]
end

function naive
    cd ~/aive/;
    nvim .;
end

