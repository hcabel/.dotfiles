set -gx CLOUDSDK_CONFIG "$HOME/.config/gcloud"
set -gx GOOGLE_APPLICATION_CREDENTIALS "$HOME/.config/gcloud/application_default_credentials.json"
set -gx AIVE_ROOT "$HOME/aive"
set -gx STACK_ROOT "$HOME/stack"
set -gx KCTX "staging-main"
source ~/.aive_secret.fish

if status is-interactive
    if test -f '/home/hcabel/google-cloud-sdk/path.fish.inc'
        source '/home/hcabel/google-cloud-sdk/path.fish.inc'
    end

    if test -f '/home/hcabel/google-cloud-sdk/completion.fish.inc'
        source '/home/hcabel/google-cloud-sdk/completion.fish.inc'
    end
end

function portfwd
    sudo -E kubefwd -A --tui -d staging -n default --kubeconfig=$HOME/.kube/config
end

function sync_app_config
    set -l config_ts "$AIVE_ROOT/src/platform-app/config.ts"
    set -l config_yaml "$AIVE_ROOT/src/platform-app/public/config.yaml"
    set -l config_bak "$config_yaml.bak"
    set -l defaults_yaml (mktemp)

    awk '/const baseSchema = z.object/,/}\)/' $config_ts | \
        sed -nE '
            s/^[[:space:]]*([a-zA-Z0-9_]+):.*z\.string.*/\1: ""/p
            s/^[[:space:]]*([a-zA-Z0-9_]+):.*z\.number.*/\1: 0/p
            s/^[[:space:]]*([a-zA-Z0-9_]+):.*z\.boolean.*/\1: false/p
            s/^[[:space:]]*([a-zA-Z0-9_]+):.*byteSizeSchema.*/\1: "0MB"/p
        ' > $defaults_yaml
    echo "featureFlag:" >> $defaults_yaml

    awk '/export const featureFlagSchema/,/}\)/' $config_ts | \
        sed -nE 's/^[[:space:]]*([a-zA-Z0-9_]+):.*/  \1: true/p' >> $defaults_yaml

    cp $config_yaml $config_bak

    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' $defaults_yaml $config_yaml > "$config_yaml.tmp"
    mv "$config_yaml.tmp" $config_yaml
    set -l diff_output (diff --color=always -u $config_bak $config_yaml | tail -n +3)

    if test (count $diff_output) -eq 0
        echo "✅ Already up to date."
    else
        echo -e "✅ Successfully synced!\n"
        printf "%s\n" $diff_output
    end

    rm $config_bak $defaults_yaml
end

function aive
    cd $AIVE_ROOT;
    if test (count $argv) -eq 0
        echo "Usage: aive <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    if not string match "*-app" $pkg
        if string match "platform-app" $pkg
            sync_app_config
        end
        aivebuild $pkg
    end
    set build_status $status
    if test $build_status -ne 0
        echo "Build failed for package $pkg"
        notify-send "Build failed: '$pkg'"
        return $build_status
    end
    if test $pkg = "graphql" -o $pkg = "sql"
        return
    end
    aiverun $pkg $args
end

function aivemake
    aive $argv
end

function aivebuild
    cd $AIVE_ROOT;
    if test (count $argv) -eq 0
        echo "Usage: aivebuild <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    make build pkg=$pkg $args
end

function aiverun
    cd $AIVE_ROOT;
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

function aivetest
    cd $AIVE_ROOT;
    if test (count $argv) -eq 0
        echo "Usage: aivetest <package> [args...]"
        return 1
    end

    set pkg $argv[1]
    set args $argv[2..-1]

    make test pkg=$pkg $args
end

function aivefmt
    cd $AIVE_ROOT;
    set pkgs (fd pkg . |  sed -E 's|./src/(.*)/pkg$|\\1|' | sort -u)
    for pkg in $pkgs
        echo "Running gofmt on package: $pkg"
        make fmt pkg=$pkg
        if test $status -ne 0
            echo "🚨 gofmt failed for package $pkg"
            notify-send "🚨 gofmt failed for package $pkg"
            return 1
        else
            echo "✅ gofmt succeeded for package $pkg"
        end
    end
end

function aivefmtgo
    cd $AIVE_ROOT;
    set pkgs (rg -l "type=go" (fd pkg "./src") | sed -E 's|./src/(.*)/pkg$|\\1|' | sort -u)
    for pkg in $pkgs
        echo "Running gofmt on package: $pkg"
        make fmt pkg=$pkg
        if test $status -ne 0
            echo "🚨 gofmt failed for package $pkg"
            notify-send "🚨 gofmt failed for package $pkg"
            return 1
        else
            echo "✅ gofmt succeeded for package $pkg"
        end
    end
end

function aivepipeline
    cd $AIVE_ROOT;
    set pkgs (tools/list-changed-packages.py origin/main | jq '.[]' -r | sort)
    aivepipeline_inner $argv[1] $pkgs
    return $status
end

function aivepipelineall
    cd $AIVE_ROOT;
    set pkgs (fd pkg "./src" | sed -E 's|^./src/([^/]+)/.*$|\1|' | sort -u)
    aivepipeline_inner $argv[1] $pkgs
    return $status
end

function aivepipelinego
    cd $AIVE_ROOT;
    set pkgs (rg -l "type=go" (fd pkg "./src") | sed -E 's|./src/(.*)/pkg$|\\1|' | sort -u)
    aivepipeline_inner $argv[1] $pkgs
    return $status
end

function aivepipeline_inner
    set skip_until $argv[1]
    set pkgs $argv[2..-1]
    set skip 1
    if not contains $skip_until $pkgs
        set skip 0
        set pkgs $argv
    end
    for pkg in $pkgs
        if test $skip -eq 1
            if test "$pkg" = "$skip_until"
                set skip 0
            else
                echo "⏭️ $pkg"
                continue
            end
        end
        echo " "
        echo " "
        echo "------------------------------------"
        echo " $pkg  "
        echo ""
        if not string match -q '*/*' -- $pkg
            make build-ci pkg=$pkg
            if test $status -ne 0
                echo ""
                echo "🚨 Build failed for package $pkg"
                echo "------------------------------------"
                notify-send "🚨 Build failed for package $pkg"
                return 1
            end
        end
        make test-ci pkg=$pkg
        if test $status -ne 0
            echo ""
            echo "🚨 Tests failed for package $pkg"
            echo "------------------------------------"
            notify-send "🚨 Tests failed for package $pkg"
            return 1
        else
            echo ""
            echo "✅ Package $pkg passed all checks!"
            echo "------------------------------------"
        end
    end
end

function old_kconfig
    kubectl get configMap/$argv -o json | jq '.data.LOGGER_FORMAT = "text" | .data | to_entries[] | "export "+.key+"=\""+.value+"\""' -r
end

function kconfig
    set -l pkg $argv[1]
    set -l env_file ~/aive/bin/$pkg.env
    if string match -q "graphql-api-*" $pkg
        set env_file ~/aive/bin/graphql-api.env
    end

    if not test -f $env_file
        echo "Error: Local env file not found at $env_file"
        return 1
    end

    kubectl get configMap/$pkg -o json | \
    jq '.data.LOGGER_FORMAT = "text" | .data | to_entries[] | "export "+.key+"=\""+.value+"\""' -r | \
    awk -v local_env="$env_file" '
        BEGIN {
            while ((getline line < local_env) > 0) {
                if (line ~ /^export [A-Za-z0-9_]+=/) {
                    sub(/^export /, "", line)
                    split(line, parts, "=")
                    local_keys[parts[1]] = 1
                }
            }
            close(local_env)
        }
        {
            line = $0
            if (line ~ /^export [A-Za-z0-9_]+=/) {
                sub(/^export /, "", line)
                split(line, parts, "=")
                if (!(parts[1] in local_keys)) {
                    print $0
                }
            }
        }
    '
end

function kuberestartedpods
    kubectl get pods | grep -e "\s[0-9]\{1,2\}\(m\|s\)\$"
end

function naive
    cd $AIVE_ROOT;
    nvim .;
end

function aivedeploy
    python3 ~/.config/fish/conf.d/aivedeploy.py $argv
end

function clone_aive_db -a db_suffix -d "Clones the main aive db into aive_<suffix>"
    if test -z "$db_suffix"
        set_color red
        echo "❌ Error: Please provide a database suffix."
        set_color normal
        echo "Usage: "(set_color yellow)"clone_aive_db"(set_color normal)" <suffix> "(set_color brblack)"(creates aive_<suffix>)"(set_color normal)
        return 1
    end

    set -l dump_file ~/latest_dump.sql
    set -l target_db aive_$db_suffix

    echo -e "\n"(set_color cyan)"🐘 Starting database clone for:"(set_color -o white)" $target_db "(set_color normal)

    set_color blue
    echo "🔄 [1/3] Dropping and creating database..."
    set_color normal

    psql "postgresql://postgres:postgres@postgres:5432/aive" -q \
        -c "DROP DATABASE IF EXISTS $target_db;" \
        -c "CREATE DATABASE $target_db WITH OWNER 'aive-owner';"

    if test $status -ne 0
        set_color red
        echo "❌ Error: Failed to setup the database."
        set_color normal
        return 1
    end

    set_color blue
    echo "💾 [2/3] Dumping 'aive' database to disk..."
    set_color normal
    pg_dump "postgresql://aive-owner:aive-owner@postgres:5432/aive" > $dump_file

    if test $status -ne 0
        set_color red
        echo "❌ Error: Database dump failed."
        set_color normal
        return 1
    end

    set_color blue
    echo "📥 [3/3] Loading dump into $target_db..."
    set_color normal

    psql -q "postgresql://aive-owner:aive-owner@postgres:5432/$target_db" < $dump_file

    if test $status -ne 0
        set_color red
        echo "❌ Error: Failed to load dump into new database."
        set_color normal
        return 1
    end

    set_color -o green
    echo "✅ Success! The database '$target_db' is ready to use."
    set_color normal
    echo ""
end
