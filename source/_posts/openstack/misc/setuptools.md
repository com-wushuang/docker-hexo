---
title:  Python打包工具 setuptools 的使用
date: 2023-01-29 15:18:17
tags:
categories: OpenStack
---

## 简述
setuptools 是一个 Python 源码打包工具，通过它，我们可以很方便的对我们的 Python 代码进行打包和分发，我们平时使用的很多第三方库，就是通过它进行打包和分发的，所以我们能够很方便的通过 pip 安装和使用，下面简单介绍下打包和分发。​

## 安装
这里需要安装几个库，setuptools是必须的，还有 wheel，用于打包成 wheel格式的二进制包，twine用于发布到 pypi

```shell
pip install setuptools wheel twine
```

## 项目结构
**项目目录树如下**
![setuptools项目目录](https://raw.githubusercontent.com/com-wushuang/pics/main/setuptools%E9%A1%B9%E7%9B%AE%E7%9B%AE%E5%BD%95.png)

**项目根目录下**
- src: 源码存放目录
- readme.md: 用于编写项目的详细描述，一般用于发布到pypi时，项目主页的描述
- setup.py: setuptools 打包配置文件

**src 源码目录下**
- demo01: Python 包，往后编写的包和Python文件，都放在这个包下，方便以后打包
- tests: Python包，一般用于编写一些测试文件，打包源码时，忽略这个包下的所有文件

**first.py 脚本测试**
```python
def test1()
    print('Hello Test1')

def test2()
    print('Hello Test2')
```

##setup.py 配置文件
```python
from setuptools import setup, find_packages
import os


# 读取文件
def read_file(filename):
    with open(os.path.join(os.path.dirname(__file__), filename), encoding='utf-8') as f:
        long_description = f.read()
    return long_description


setup(
    # 基本信息
    name="demo01",  # 项目名，确定唯一，不然上传 pypi 会失败
    version="1.0.0",  # 项目版本
    author='cjlmonster',  # 开发者
    author_email='cjlmonster@163.com',  # 开发者邮箱
    description='这是一个测试项目',  # 摘要描述
    long_description=read_file('readme.md'),  # 详细描述，一般用于 pypi 主页展示
    long_description_content_type="text/markdown",  # 详细描述的文件类型
    platforms='python3',  # 项目支持的平台
    url='https://www.cjlmonster.cn',  # 项目主页

    # 项目配置
    # 包含所有src文件夹下的包，但排除tests包
    packages=find_packages('src', exclude=['*.tests', '*.tests.*', 'tests.*', 'tests']),
    package_dir={'': 'src'},  # find_packages指定了文件夹后，这里也需要配置
    package_data={
        # 任何包中含有.txt文件，都包含它
        '': ['*.txt']

    },
    exclude_package_data={
        # 忽略demo01包下的data文件夹里的abc.txt文件
        'demo01': ['data/abc.txt']
    },
    # 支持Python版本
    python_requires='>=3',
    # 表明当前模块依赖哪些包，若环境中没有，则会从pypi中下载安装
    install_requires=[
        'flask >= 2.0.1',
        'pillow >= 6.2.2, < 7.0.0'
    ],
    # 用来支持自动生成脚本，如下配置
    # 在类Unix系统下，会在 /usr/local/bin下生成 test1和test2 两个命令
    # 在Windows系统下，会在当前Python环境下的 scripts 目录下生成 test1.exe和test2.exe
    entry_points={
        'console_scripts': [
            'test1 = demo01.first:test1',  # 入口指向demo01包下的first文件里的 test1 函数
            'test2 = demo01.first:test2',  # 入口指向demo01包下的first文件里的 test2 函数
        ],
    }
)
```
- 编写完配合文件后，可以直接安装源码到本地环境
```python
python setup.py install
```
- 测试阶段不想直接安装到本地的话，可以使用
```python
python setup.py develop
```

## 打包源码
- 上面开发完项目之后，编写 setup.py 打包配置文件，之后就可以使用 setuptools 打包了，这里打包为 wheel 格式的二进制文件，项目根目录下执行如下命令打包：
```shell
python setup.py bdist_wheel
```
- 执行打包命令，会生成一些发布文件：
![bdist_whell](https://raw.githubusercontent.com/com-wushuang/pics/main/bdist_whell.png)

- 其中 dist 目录下的 `demo01-1.0.0-py3-none-any.whl` 就是打包好的项目源码，查看它

- 直接安装到本地：
```shell
pip install dist/demo01-1.0.0-py3-none-any.whl
```

- 查看安装依赖
```
pip show demo1
```
- 脚本命令
```
$ test1
Hello Test1

$ test2
Hello Test2
```

## 发布
项目开发好后，想分享给更多人使用时，打包后还需要上传到 PyPi （Python Package Index）上，它是 Python 官方维护的第三方包仓库，用于统一存储和管理开发者发布的 Python 包。​

- 首先需要在 PyPi 上注册账号​

- 然后在用户家目录下生成 ~/.pypirc 文件，并编写如下内容
```ini
[distutils]
index-servers = pypi

[pypi]
username:xxx
password:xxx
```
- 然后使用这条命令进行信息注册
```shell
python setup.py register
```
- 注册完了后，上传源码包
```shell
python setup.py upload
```
- 上面的发布是 setuptools 自带的，操作比较麻烦，想要简单点，可以使用 twine 发布工具，直接输入:
```shell
twine upload dist/demo01-1.0.0-py3-none-any.whl
```
- 上传到 pypi 后，就可以在 pypi 上看到项目的信息了，并且可以使用 pip 进行安装使用
```shell
pip install demo01
```