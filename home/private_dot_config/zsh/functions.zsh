build_clean_all () {
  pushd .;
  currDir=`pwd`
  for i in `find $currDir -maxdepth 7 -type d \( -name ".git" -o -name ".svn" \)`; do
    if [ -f $i/../pom.xml ]
    then
      cd $i/../ > /dev/null;
      pwd;
      mvn clean > /dev/null;
    fi
    if [ -f $i/../build.gradle ]
    then
      cd $i/../ > /dev/null;
      pwd;
      ./gradlew clean > /dev/null;
    fi
  done;
  popd;
}

mvn_plugin_updates () {
  mvn versions:display-plugin-updates | grep -- "->" | sort | uniq
}

mvn_dependency_updates () {
  mvn versions:display-dependency-updates | grep -- "->" | sort | uniq
}

git_update_all () {
  pushd .;
  currDir=`pwd`
  for i in `find $currDir -maxdepth 7 -type d -name ".git"`; do
    cd $i/../ > /dev/null;
    pwd;
    git pull > /dev/null;
    if [ $? -ne 0 ]; then
      echo "git pull error";
      return;
    fi
  done;
  popd;
}

svn_update_all () {
  pushd .;
  currDir=`pwd`
  for i in `find $currDir -maxdepth 7 -type d -name ".svn"`; do
    cd $i/../ > /dev/null;
    pwd;
    svn up > /dev/null;
    if [ $? -ne 0 ]; then
      echo "svn up error";
      return;
    fi
  done;
  popd;
}

vcs_update_all () {
  git_update_all
  svn_update_all
}

vcs_clean_ignored () {
  pushd .;
  currDir=`pwd`
  for i in `find $currDir -maxdepth 7 -type d -name ".git"`; do
    cd $i/../ > /dev/null;
    pwd;
    git clean -dfx
  done;
  for i in `find $currDir -maxdepth 7 -type d -name ".svn"`; do
    cd $i/../ > /dev/null;
    pwd;
    svn status --no-ignore | grep '^I' | sed 's/^I       //' | xargs rm -rf
  done;
  popd;
}

kralpine () {
  kubectl run -i --rm --tty alpine --image=alpine -- sh
}

kexec () {
  kubectl exec -it $1 -- ${2:-bash}
}

asdf_latest_versions () {
  asdf update > /dev/null 2>&1
  asdf plugin update --all > /dev/null 2>&1
  diff <(cat ~/.tool-versions | awk '{print $1}' | xargs -I {} bash -c 'echo {} $(asdf latest {})') <(cat ~/.tool-versions)
}
