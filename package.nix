{ lib
, stdenv
, fetchFromGitHub
, jdk8
, gradle_7
, perl
, makeWrapper
, udev
}:
let
  # Most of the code here is stolen from various gradle 
  # packages in nixpkgs 
  # primarily https://github.com/NixOS/nixpkgs/blob/fcb6648102a7df48d71c7aa5dfd31673934a1eac/pkgs/tools/typesetting/pdftk/default.nix

  pname = "ATLauncher";
  version = "3.4.20.2";

  src = fetchFromGitHub {
    owner = "ATLauncher";
    repo = pname;

    rev = "v${version}";
    hash = "sha256-obrouGa/JyONT88D8DpwOCLlOqVZKM45GeNOijfPw/Y=";
  };
  # Adds a gradle step that downloads all the dependencies to the gradle cache.
  addResolveStep = ''
        cat >>build.gradle <<HERE
    task resolveDependencies {
      doLast {
        project.rootProject.allprojects.each { subProject ->
          subProject.buildscript.configurations.each { configuration ->
            resolveConfiguration(subProject, configuration, "buildscript config \''${configuration.name}")
          }
          subProject.configurations.each { configuration ->
            resolveConfiguration(subProject, configuration, "config \''${configuration.name}")
          }
        }
      }
    }
    void resolveConfiguration(subProject, configuration, name) {
      if (configuration.canBeResolved) {
        logger.info("Resolving project {} {}", subProject.name, name)
        configuration.resolve()
      }
    }
    HERE
  '';
  deps = stdenv.mkDerivation {
    pname = "${pname}-deps";
    inherit version src;

    nativeBuildInputs = [ gradle_7 perl ];

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d)
      gradle --no-daemon shadowJar -x test
    '';

    # perl code mavenizes pathes (com.squareup.okio/okio/1.13.0/a9283170b7305c8d92d25aff02a6ab7e45d06cbe/okio-1.13.0.jar -> com/squareup/okio/okio/1.13.0/okio-1.13.0.jar)
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh

      ln -s $out/com/squareup/okio/okio/2.8.0/okio-jvm-2.8.0.jar $out/com/squareup/okio/okio/2.8.0/okio-2.8.0.jar
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-KzfYsirUHuwuk8G31zRPEgJDpoLt001+dfJoXFAUVMk=";
  };

in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ jdk8 gradle_7 makeWrapper ];

  buildPhase = ''
    runHook preBuild

    export GRADLE_USER_HOME=$(mktemp -d)
    # ln -s ${deps} dependencies
    # sed -i "s#mavenLocal()#mavenLocal(); maven { url '${deps}' }#g" build.gradle

    gradleInit=$(mktemp)
    cat >$gradleInit <<EOF
      gradle.projectsLoaded {
        rootProject.allprojects {
          buildscript {
            repositories {
              clear()
              maven { url '${deps}' }
            }
          }
          repositories {
            clear()
            maven { url '${deps}' }
          }
        }
      }
      settingsEvaluated { settings ->
        settings.pluginManagement {
          repositories {
            maven { url '${deps}' }
          }
        }
      }
    EOF

    gradle --offline --no-daemon --info -Dorg.gradle.java.home=${jdk8} --init-script $gradleInit shadowJar -x test

    runHook postBuild
  '';

  installPhase =
    ''
      runHook preInstall

      mkdir -p $out/{bin,share/}
      cp build/libs/${pname}-${version}.jar $out/share/${pname}.jar

      makeWrapper ${jdk8}/bin/java $out/bin/atlauncher \
        --prefix LD_LIBRARY_PATH : ${udev}/lib \
        --add-flags "-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -jar $out/share/${pname}.jar"

      mkdir -p $out/share/applications

      cp packaging/linux/_common/atlauncher.desktop $out/share/applications

      runHook postInstall
    '';
}
