. $(dirname $0)/gerrit-credentials

export THT=$HOME/tripleo-heat-templates
export PP=/etc/puppet/modules/tripleo

co_repo()
{
local os_project=$1
local co_dir=$2
local review=$3
git clone https://github.com/openstack/${os_project} ${co_dir}
pushd $co_dir &>/dev/null
git remote add gerrit https://${GITREVIEW_USERNAME}@review.openstack.org/openstack/${os_project}.git
git config gitreview.username ${GITREVIEW_USERNAME}
git config user.name ${GIT_USER_NAME}
git config user.email ${GIT_USER_EMAIL}
if [ -n "$review" ]; then
    git review -d $review
else
    git review -s
fi
popd &>/dev/null
}

link_repo()
{
local current_dir=$PWD
local dest_dir=$1
local files=$(git diff-tree --no-commit-id --name-only -r HEAD)
pushd $dest_dir &>/dev/null
for f in $files; do
    echo $current_dir/$f "->" $dest_dir/$f
    mkdir -p $(dirname ./$f); rm -f $f; ln -nf $current_dir/$f $f
done
popd &>/dev/null
}
