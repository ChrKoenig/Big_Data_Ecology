Version Control
================
Christian König

**This practical exercise is a part of the workshop [Big Data
Ecology](https://github.com/ChrKoenig/Big_Data_Ecology)**

------------------------------------------------------------------------

## Introduction

In the [thematic excursion on version
control](https://github.com/ChrKoenig/Big_Data_Ecology/blob/main/lectures/version_control.pdf),
we learned about the basics of version control, why it is important for
a reproducible and fail-safe workflow, and how it is implemented in the
most widely used version control software, git. Here, we want to get
some hands-on experience with it.

If you haven’t installed git yet, please go
[download](https://git-scm.com/downloads) it and do so. Also make sure
to have a working account on [Github](https://github.com) or at the
University of Potsdams’ version control platform,
[GitUP](https://gitup.uni-potsdam.de/).

We will be working with git from the command line. On UNIX-systems, git
natively integrates with the terminal, which can be accessed with
`Alt + T`. On Windows, git comes with a command line tool named Git
Bash, which emulates a Unix terminal and can be used for this practical.

If you are using git for the *very fist time*, you have set up some
things. Most importantly, you should tell git your name and your email
address, as these information are part of every commit you make. We set
these parameters globally, so we don’t need set them again them when
creating a new repository.

``` bash
git config --global user.name "My Name"
git config --global user.email mymail@uni-potsdam.com
```

Of course, you can [set many more
options](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)
with `git config` if you want to further customize git.

## Set up a repository

To get started, we create a new folder `git_exercise` in a suitable
location of our file system. This will be our working directory.

``` bash
mkdir ~/Documents/git_exercise    # create new folder
```

Now that we have created a new directory, we can put it under version
control by initializing a git repository at its top level.

``` bash
cd ~/Documents/git_exercise       # switch to new folder
git init                          # initialize git repo
```

    ## Initialized empty Git repository in /home/christian/Documents/git_exercise/.git/

There are currently no files in the repository, so let’s create an empty
text file.

``` bash
touch new_file.txt
```

This file now lives in the working tree, i.e. git is aware of it but
does not track changes yet. We can verify this with `git status`.

``` bash
git status
```

    ## On branch master
    ## 
    ## No commits yet
    ## 
    ## Untracked files:
    ##   (use "git add <file>..." to include in what will be committed)
    ##  new_file.txt
    ## 
    ## nothing added to commit but untracked files present (use "git add" to track)

As you can see, `git status` shows a very concise but informative
overview of your repository, e.g. which branch we are working on and
which files have been modified. It is generally a good habit to run this
command often, especially before making major changes to the repository.

**A quick note on branches:** Note that our local repository currently
contains only one branch, which is named *master* by convention.
However, you can [create multiple
branches](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging)
within your project and work on them separately. For example, we might
be experimenting with a new model type but don’t want to mess up our
thoroughly tested and functional code on the master branch. In this
case, we could simply create a new branch with `git branch new_model`
and switch to it with `git checkout new_model`. Now we can safely work
on the implementation of the model without interfering with the master
branch. Later, we can commit our changes and merge the `new_model`
branch back into `master`. While we will not be working with local
branches in this practical, it may come in handy for your future
projects.

## Making changes to the repository

Back to our `master` repo and the file we just created: In order to
track the changes in `new_file.txt`, we first need to `add` it to the
staging area.

``` bash
git add new_file.txt
```

However, only with our next `commit`, git will include `new_file.txt`
into the repository and put it under version control.

Each commit requires a commit message that summarizes the changes that
have been made. This message should be **concise but expressive**, so it
will help you and others to quickly understand what this commit was
about. It is good practice to commit changes in thematically coherent
chunks, e.g. after finishing an important part of your analysis script
or re-organizing files. Commit often!

For convenience, we provide the commit message along with the command,
using the `-m` flag. Alternatively, a text editor opens and we can type
our commit message there.

``` bash
git commit -m "Initial commit"
```

    ## [master (root-commit) 8f3de49] Initial commit
    ##  1 file changed, 0 insertions(+), 0 deletions(-)
    ##  create mode 100644 new_file.txt

Nice! We have just successfully used the core functionality of git.
While we could keep working locally, it is often better to synchronize
your work with a remote repository to avoid data loss in case something
happens to your computer. Moreover, adding a remote repository allows us
to collaborate with other people on a project.

## Working with a remote repository

There are different ways to set up a remote repository in git. When
working with GitHub or GitLab (which powers the GitUP platform of the
University of Potsdam), the easiest way to add a remote repository to an
existing local repository is to log into the website, create a new
project and register it as a remote location.

``` bash
# Github
git remote add origin https://github.com/USER/REPO.git           # adapt to your user and repo name
# Gitlab
git remote add origin https://gitup.uni-potsdam.de/USER/REPO.git # adapt to your user and repo name

# verify remote URL
git remote -v
```

By convention, the remote repository is named “origin” because it
usually is the central hub in projects with multiple contributors. With
the above command, we told git to remember the URL whenever we reference
`origin`. We now `push` our local files to the remote, further
specifying that `origin` is the *upstream* repository (`-u` flag),
i.e. the default location to `push` changes to.

``` bash
git push -u origin --all    # Push local files to remote repository
```

    ## To https://github.com/ChrKoenig/example_remote.git
    ##  * [new branch]      master -> master
    ## Branch 'master' set up to track remote branch 'master' from 'origin'.

If everything worked as intended, the `new_file.txt` we just created
locally should now be in the remote repository.

Now imagine that we have another local repository on a different
machine, for example on a compute cluster to run longer calculations.
There, we found a bug in the code, fixed it, and pushed the changes back
to `origin`. In this case, the *“remote contains work that you don’t
have locally”*. To emulate this situation, open the newly added text
file on the GitHub/GitUP website, make some modifications, and commit
your changes.

To incorporate these changes into our local repository, we need to
`pull` them.

``` bash
git pull origin master
```

    ## From https://github.com/ChrKoenig/example_remote
    ##  * branch            master     -> FETCH_HEAD
    ##    8f3de49..89c7ff9  master     -> origin/master
    ## Updating 8f3de49..89c7ff9
    ## Fast-forward
    ##  new_file.txt | 1 +
    ##  1 file changed, 1 insertion(+)

In fact, `pull` is a shorthand for two operations: `fetch` and `merge`
(see also lecture slides). `Fetch` copies the remote files into our
local repository, while `merge` tries to, well, merge these changes with
our local files. If you have made changes to those files yourself and
they affect the same parts of the code, you will run into *merge
conflicts* which need to be resolved manually or using the [git
mergetool](https://git-scm.com/docs/git-mergetool). Luckily, there
should not be any merge conflicts this time.

``` bash
git status
```

    ## On branch master
    ## Your branch is up to date with 'origin/master'.
    ## 
    ## nothing to commit, working tree clean

## Some final notes

Many modern IDEs such as RStudio or VSCode provide a more user-friendly
interface to the most common git operations. This is great! However,
while the command line may not be the most comfortable way to use git,
it surely is the most effective way to build a solid understanding of
the software. At some point you will run into a problem that cannot be
solved from within your IDE – it’s not a coincidence that five out of
the ten [top-voted questions on
StackOverflow](https://stackoverflow.com/questions?sort=MostVotes&edited=true)
are related to git. Then, some familiarity with the git command line
will be of great help.

## Exercise

Now, try to set up a git repository for our course project:

-   Create a new folder for the course project and put it under version
    control
-   Within the repository, create a new R-Project and add an .R file for the analysis script.
    You can use the template from
    [here](https://github.com/ChrKoenig/Big_Data_Ecology/blob/main/project/course_project.R).
-   Create a new project on Github/GitUP and add it as a remote upstream
    to your local project
-   Commit your local changes and push them to your remote repo
-   Make yourself familiar with the integration of Git into RStudio. Can
    you manage your repository from within RStudio?
