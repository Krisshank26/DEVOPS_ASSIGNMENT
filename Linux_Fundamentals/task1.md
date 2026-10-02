# Linux Fundamentals 

## Difference between Soft Link and Hard Link 

Soft Link- Soft link (or sumbolic links, symlinks ) is a special file in an Operating System that stores a text-based path pointer shortcut to another file in the system. It does not store the actual file contents of a file but only the path to it. Soft links can be applied to files as well as directories. If the original file is deleted then, the soft link becomes a "dangling pointer" to that file path, which does not exist now, and the actual contents are also deleted from the system. 

Hard link- Hard link is a direct pointer to the Inode Number of file in an Operating System. If accessing a file through hard link it will return the actual contents of the original file. Hard links can only be applied to files, because using them for directories can cause infinite recursive traversal in a file system, for example, you store the hard link of a parent folder in a child foler inside it. If the actual file is deleted, the contents of the file are not deleted and we can still access contents, if atleast one hard link to it exists. 

![Task 1 ](Linux_1.png ) 

