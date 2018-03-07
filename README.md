Shun
====

*"Shun is tool to print Shellcheck statistics from a Git repository"*

Who's next ? Who will pay fresh croissants or  pastries for his colleagues ?

## Install

```
$ sudo make install
$ sudo make uninstall
$ shun -h
```

## Usage

* Prints statistics per *shellcheck* code for the current month, that belongs to `John Smith` (`<path>`: must be a file or a directory that comes from a *git* repository.):

```
$ shun -m -a 'John Smith' -s <path>
```

* Prints *shellcheck*-warning line number for the current week, written by `John Smith` :

```
$ shun -b <path> -w -a 'John Smith'
```

* Prints *shellcheck*-warning lines statistics for the current year:

```
$ shun -b <path> -y
```
