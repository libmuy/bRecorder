# brecorder

# Move Object between Repo(Cloud)

1. delete from source repo
   1. delete from cloud
   2. delete from local file system cache
   3. remove object from memory cache
2. add to target repo
   1. add to file system cache
   2. add to memory cache
   3. upload(sync) to cloud

# Cloud Sync usecase

1. File operations in local side
   this doesn't include file operation out of app(the folder is not visable out of app)
2. File operations in cloud side
3. File Operations
   - Delete
   - Add
   - Move

# Cloud Sync Policy

Using local for default policy

# Known problems

1. File options doing in both local side and cloud side will result in unexpected result.

