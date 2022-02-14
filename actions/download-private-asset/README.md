# Download private repo asset with PAT (Personal Access Token)

## Usage

```yaml
    - uses: gameanalytics/github/actions/download-private-asset@v0
      with:
        repo: orgname/reponame
        version: 1.0.0
        asset: assetname-1.0.0-...whl
      env:
        # Your personal access token which
        #  accesses the private asset
        token: ${{ secrets.TOKEN }}
```

Or

```yaml
    - uses: gameanalytics/github/actions/download-private-asset@v0
      with:
        repo: orgname/reponame
        version: latest
        asset: projectname-latest.zip
      env:
        # Your personal access token which
        #  accesses the private asset
        token: ${{ secrets.TOKEN }}
```

## Credits

* https://gist.github.com/maxim/6e15aa45ba010ab030c4
* https://github.com/wyozi/download-gh-release-asset
