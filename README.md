# NVFlare in Cancer Research 

We are setting up a project to explore federated learning using NVFlare. We assume that the participants will have one of these options available: 

- A AWS or Azure cloud account
- An on-premises Slurm HPC system with GPU 
- A Windows Laptop with a GPU installed 

The central NVFlare server including dashboard with be installed by the IT department of one of the participating institutions. The researchers in this institution will use an NVFlare compute client on their HPC system and will have no access to the central system. 

For consistency reasons we recommend installing the lastest NVFlare supported Python version (3.10 as of May 2024) from the same source. We propose the Rye Package manager by Armin Ronacher (the maker of Flask). Below are the instructions for Linux / Mac, please see Windows instructions [here](https://rye-up.com/). It will install the Rye package manager, which installs Python 3.10 and make it the default Python on your system (it will edit file ~/.python-version)

```
curl -sSf https://rye-up.com/get | bash
. ~/.rye/env
rye toolchain fetch 3.10
rye pin 3.10
```

The Rye installer will put `. ~/.rye/env` into ~/.profile to ensure that the environment is ready at the next login. If you have an older HPC system it may not use the file ~/.profile but ~/.bash_profile instead. just run `echo '. ~/.rye/env' >> ~/.bash_profile` in that case. 

A quick test should show that the default python is latest Python 3.10

```
$ python --version
Python 3.10.14
```

install NVFlare in a virtual environment created by `uv` 

```
$ uv venv ~/.local/nvf
Using Python 3.10.14 interpreter at: .rye/py/cpython@3.10.14/bin/python3
Creating virtualenv at: .local/nvf
Activate with: source .local/nvf/bin/activate

$ source ~/.local/nvf/bin/activate
(nvf) $ uv pip install nvflare
```

if you plan to work with your NVFlare project for a while you should consider automatically activating when you login, e.g. 

```
echo 'source ~/.local/nvf/bin/activate' >> ~/.profile  # or ~/.bash_profile
```







