This Github Action builds and optionally pushes a docker image to the [*DockerHub*](https://docs.docker.com/docker-hub/) and [*GitHub*](https://help.github.com/github/managing-packages-with-github-package-registry/configuring-docker-for-use-with-github-package-registry) registries. Hereby the `master` branch is published as the `latest` tag. Otherwise the branch name is published as the tag. Git tagging is considered and published as well.

### Example pipeline

```yaml
name: Dockerization
on:
  push:
    # paths:
    #   - 'path/**'
    paths-ignore:
      - '**.md'
jobs:
  build:
    name: dockerize
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
    - name: Print environment
      run: |
        printenv | grep GITHUB_
    - name: Build and publish
      uses: dta4/hub/dockerize@master
      with:
        image: foo
        github_token: ${{ secrets.GITHUB_TOKEN }}
        docker_token: ${{ secrets.DOCKER_TOKEN }}
 ```

### Inputs

| name | description | default |
| --- | --- | --- |
| context | build context | `.` |
| **image** | image name | {{context}} |
| username | account on *DockerHub* and *GitHub* | `GITHUB_ACTOR` |
| github_token | password for *GitHub* | |
| docker_token | password for *DockerHub* | |
| owner | owner of *DockerHub* and *GitHub* | **owner**/repo part of `GITHUB_REPOSITORY` |
| github_repository | repository of *GitHub* | owner/**repo** part of `GITHUB_REPOSITORY` |
| docker_repository | repository of *DockerHub* |  owner/**repo** part of `GITHUB_REPOSITORY` |
| image_suffixing | append image name to *DockerHub* tag | `false` |
| publish | enable pushing to *DockerHub* and *GitHub* | `false` |

:bulb: Actual convention is, to have the same `login` name and repository `owner` on *DockerHub* and *GitHub*.

### Outputs

`docker-tag` is the tag, which was pushed to *DockerHub*

`docker-github-tag` is the tag, which was pushed to *GitHub*

### DockerHub vs. GitHub

* *DockerHub* registry: `docker.io`
* *GitHub* registry: `docker.pkg.github.com`
* t.d.b...
  * different schemes
  * anonymous *GitHub*

### TODO

* [ ] tag the [SemVer](https://semver.org/) cascade: `1.42.3`,`1.42`,`1`
* [ ] evaluate [Kaniko](https://github.com/GoogleContainerTools/kaniko) instead of [Docker in Docker](https://hub.docker.com/_/docker/)
