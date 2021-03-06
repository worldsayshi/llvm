.. _gold-plugin:

====================
The LLVM gold plugin
====================

.. sectionauthor:: Nick Lewycky

Introduction
============

Building with link time optimization requires cooperation from
the system linker. LTO support on Linux systems requires that you use the
`gold linker`_ which supports LTO via plugins. This is the same mechanism
used by the `GCC LTO`_ project.

The LLVM gold plugin implements the gold plugin interface on top of
:ref:`libLTO`.  The same plugin can also be used by other tools such as
``ar`` and ``nm``.

.. _`gold linker`: http://sourceware.org/binutils
.. _`GCC LTO`: http://gcc.gnu.org/wiki/LinkTimeOptimization
.. _`gold plugin interface`: http://gcc.gnu.org/wiki/whopr/driver

.. _lto-how-to-build:

How to build it
===============

You need to have gold with plugin support and build the LLVMgold plugin.
Check whether you have gold running ``/usr/bin/ld -v``. It will report "GNU
gold" or else "GNU ld" if not. If you have gold, check for plugin support
by running ``/usr/bin/ld -plugin``. If it complains "missing argument" then
you have plugin support. If not, such as an "unknown option" error then you
will either need to build gold or install a version with plugin support.

* To build gold with plugin support:

  .. code-block:: bash

     $ mkdir binutils
     $ cd binutils
     $ cvs -z 9 -d :pserver:anoncvs@sourceware.org:/cvs/src login
     {enter "anoncvs" as the password}
     $ cvs -z 9 -d :pserver:anoncvs@sourceware.org:/cvs/src co binutils
     $ mkdir build
     $ cd build
     $ ../src/configure --enable-gold --enable-plugins
     $ make all-gold

  That should leave you with ``binutils/build/gold/ld-new`` which supports
  the ``-plugin`` option. It also built would have
  ``binutils/build/binutils/ar`` and ``nm-new`` which support plugins but
  don't have a visible -plugin option, instead relying on the gold plugin
  being present in ``../lib/bfd-plugins`` relative to where the binaries
  are placed.

* Build the LLVMgold plugin: Configure LLVM with
  ``--with-binutils-include=/path/to/binutils/src/include`` and run
  ``make``.

Usage
=====

The linker takes a ``-plugin`` option that points to the path of
the plugin ``.so`` file. To find out what link command ``gcc``
would run in a given situation, run ``gcc -v [...]`` and
look for the line where it runs ``collect2``. Replace that with
``ld-new -plugin /path/to/LLVMgold.so`` to test it out. Once you're
ready to switch to using gold, backup your existing ``/usr/bin/ld``
then replace it with ``ld-new``.

You can produce bitcode files from ``clang`` using ``-emit-llvm`` or
``-flto``, or the ``-O4`` flag which is synonymous with ``-O3 -flto``.

Any of these flags will also cause ``clang`` to look for the gold plugin in
the ``lib`` directory under its prefix and pass the ``-plugin`` option to
``ld``. It will not look for an alternate linker, which is why you need
gold to be the installed system linker in your path.

If you want ``ar`` and ``nm`` to work seamlessly as well, install
``LLVMgold.so`` to ``/usr/lib/bfd-plugins``. If you built your own gold, be
sure to install the ``ar`` and ``nm-new`` you built to ``/usr/bin``.


Example of link time optimization
---------------------------------

The following example shows a worked example of the gold plugin mixing LLVM
bitcode and native code.

.. code-block:: c

   --- a.c ---
   #include <stdio.h>

   extern void foo1(void);
   extern void foo4(void);

   void foo2(void) {
     printf("Foo2\n");
   }

   void foo3(void) {
     foo4();
   }

   int main(void) {
     foo1();
   }

   --- b.c ---
   #include <stdio.h>

   extern void foo2(void);

   void foo1(void) {
     foo2();
   }

   void foo4(void) {
     printf("Foo4");
   }

.. code-block:: bash

   --- command lines ---
   $ clang -flto a.c -c -o a.o      # <-- a.o is LLVM bitcode file
   $ ar q a.a a.o                   # <-- a.a is an archive with LLVM bitcode
   $ clang b.c -c -o b.o            # <-- b.o is native object file
   $ clang -flto a.a b.o -o main    # <-- link with LLVMgold plugin

Gold informs the plugin that foo3 is never referenced outside the IR,
leading LLVM to delete that function. However, unlike in the :ref:`libLTO
example <libLTO-example>` gold does not currently eliminate foo4.

Quickstart for using LTO with autotooled projects
=================================================

Once your system ``ld``, ``ar``, and ``nm`` all support LLVM bitcode,
everything is in place for an easy to use LTO build of autotooled projects:

* Follow the instructions :ref:`on how to build LLVMgold.so
  <lto-how-to-build>`.

* Install the newly built binutils to ``$PREFIX``

* Copy ``Release/lib/LLVMgold.so`` to ``$PREFIX/lib/bfd-plugins/``

* Set environment variables (``$PREFIX`` is where you installed clang and
  binutils):

  .. code-block:: bash

     export CC="$PREFIX/bin/clang -flto"
     export CXX="$PREFIX/bin/clang++ -flto"
     export AR="$PREFIX/bin/ar"
     export NM="$PREFIX/bin/nm"
     export RANLIB=/bin/true #ranlib is not needed, and doesn't support .bc files in .a
     export CFLAGS="-O4"

* Or you can just set your path:

  .. code-block:: bash

     export PATH="$PREFIX/bin:$PATH"
     export CC="clang -flto"
     export CXX="clang++ -flto"
     export RANLIB=/bin/true
     export CFLAGS="-O4"
* Configure and build the project as usual:

  .. code-block:: bash

     % ./configure && make && make check

The environment variable settings may work for non-autotooled projects too,
but you may need to set the ``LD`` environment variable as well.

Licensing
=========

Gold is licensed under the GPLv3. LLVMgold uses the interface file
``plugin-api.h`` from gold which means that the resulting ``LLVMgold.so``
binary is also GPLv3. This can still be used to link non-GPLv3 programs
just as much as gold could without the plugin.
