.. _how-to-set-up-llvm-style-rtti:

======================================================
How to set up LLVM-style RTTI for your class hierarchy
======================================================

.. sectionauthor:: Sean Silva <silvas@purdue.edu>

.. contents::

Background
==========

LLVM avoids using C++'s built in RTTI. Instead, it  pervasively uses its
own hand-rolled form of RTTI which is much more efficient and flexible,
although it requires a bit more work from you as a class author.

A description of how to use LLVM-style RTTI from a client's perspective is
given in the `Programmer's Manual <ProgrammersManual.html#isa>`_. This
document, in contrast, discusses the steps you need to take as a class
hierarchy author to make LLVM-style RTTI available to your clients.

Before diving in, make sure that you are familiar with the Object Oriented
Programming concept of "`is-a`_".

.. _is-a: http://en.wikipedia.org/wiki/Is-a

Basic Setup
===========

This section describes how to set up the most basic form of LLVM-style RTTI
(which is sufficient for 99.9% of the cases). We will set up LLVM-style
RTTI for this class hierarchy:

.. code-block:: c++

   class Shape {
   public:
     Shape() {}
     virtual double computeArea() = 0;
   };

   class Square : public Shape {
     double SideLength;
   public:
     Square(double S) : SideLength(S) {}
     double computeArea() /* override */;
   };

   class Circle : public Shape {
     double Radius;
   public:
     Circle(double R) : Radius(R) {}
     double computeArea() /* override */;
   };

The most basic working setup for LLVM-style RTTI requires the following
steps:

#. In the header where you declare ``Shape``, you will want to ``#include
   "llvm/Support/Casting.h"``, which declares LLVM's RTTI templates. That
   way your clients don't even have to think about it.

   .. code-block:: c++

      #include "llvm/Support/Casting.h"

#. In the base class, introduce an enum which discriminates all of the
   different concrete classes in the hierarchy, and stash the enum value
   somewhere in the base class.

   Here is the code after introducing this change:

   .. code-block:: c++

       class Shape {
       public:
      +  /// Discriminator for LLVM-style RTTI (dyn_cast<> et al.)
      +  enum ShapeKind {
      +    SK_Square,
      +    SK_Circle
      +  };
      +private:
      +  const ShapeKind Kind;
      +public:
      +  ShapeKind getKind() const { return Kind; }
      +
         Shape() {}
         virtual double computeArea() = 0;
       };

   You will usually want to keep the ``Kind`` member encapsulated and
   private, but let the enum ``ShapeKind`` be public along with providing a
   ``getKind()`` method. This is convenient for clients so that they can do
   a ``switch`` over the enum.

   A common naming convention is that these enums are "kind"s, to avoid
   ambiguity with the words "type" or "class" which have overloaded meanings
   in many contexts within LLVM. Sometimes there will be a natural name for
   it, like "opcode". Don't bikeshed over this; when in doubt use ``Kind``.

   You might wonder why the ``Kind`` enum doesn't have an entry for
   ``Shape``. The reason for this is that since ``Shape`` is abstract
   (``computeArea() = 0;``), you will never actually have non-derived
   instances of exactly that class (only subclasses). See `Concrete Bases
   and Deeper Hierarchies`_ for information on how to deal with
   non-abstract bases. It's worth mentioning here that unlike
   ``dynamic_cast<>``, LLVM-style RTTI can be used (and is often used) for
   classes that don't have v-tables.

#. Next, you need to make sure that the ``Kind`` gets initialized to the
   value corresponding to the dynamic type of the class. Typically, you will
   want to have it be an argument to the constructor of the base class, and
   then pass in the respective ``XXXKind`` from subclass constructors.

   Here is the code after that change:

   .. code-block:: c++

       class Shape {
       public:
         /// Discriminator for LLVM-style RTTI (dyn_cast<> et al.)
         enum ShapeKind {
           SK_Square,
           SK_Circle
         };
       private:
         const ShapeKind Kind;
       public:
         ShapeKind getKind() const { return Kind; }

      -  Shape() {}
      +  Shape(ShapeKind K) : Kind(K) {}
         virtual double computeArea() = 0;
       };

       class Square : public Shape {
         double SideLength;
       public:
      -  Square(double S) : SideLength(S) {}
      +  Square(double S) : Shape(SK_Square), SideLength(S) {}
         double computeArea() /* override */;
       };

       class Circle : public Shape {
         double Radius;
       public:
      -  Circle(double R) : Radius(R) {}
      +  Circle(double R) : Shape(SK_Circle), Radius(R) {}
         double computeArea() /* override */;
       };

#. Finally, you need to inform LLVM's RTTI templates how to dynamically
   determine the type of a class (i.e. whether the ``isa<>``/``dyn_cast<>``
   should succeed). The default "99.9% of use cases" way to accomplish this
   is through a small static member function ``classof``. In order to have
   proper context for an explanation, we will display this code first, and
   then below describe each part:

   .. code-block:: c++

       class Shape {
       public:
         /// Discriminator for LLVM-style RTTI (dyn_cast<> et al.)
         enum ShapeKind {
           SK_Square,
           SK_Circle
         };
       private:
         const ShapeKind Kind;
       public:
         ShapeKind getKind() const { return Kind; }

         Shape(ShapeKind K) : Kind(K) {}
         virtual double computeArea() = 0;
       };

       class Square : public Shape {
         double SideLength;
       public:
         Square(double S) : Shape(SK_Square), SideLength(S) {}
         double computeArea() /* override */;
      +
      +  static bool classof(const Shape *S) {
      +    return S->getKind() == SK_Square;
      +  }
       };

       class Circle : public Shape {
         double Radius;
       public:
         Circle(double R) : Shape(SK_Circle), Radius(R) {}
         double computeArea() /* override */;
      +
      +  static bool classof(const Shape *S) {
      +    return S->getKind() == SK_Circle;
      +  }
       };

   The job of ``classof`` is to dynamically determine whether an object of
   a base class is in fact of a particular derived class.  In order to
   downcast a type ``Base`` to a type ``Derived``, there needs to be a
   ``classof`` in ``Derived`` which will accept an object of type ``Base``.

   To be concrete, consider the following code:

   .. code-block:: c++

      Shape *S = ...;
      if (isa<Circle>(S)) {
        /* do something ... */
      }

   The code of the ``isa<>`` test in this code will eventually boil
   down---after template instantiation and some other machinery---to a
   check roughly like ``Circle::classof(S)``. For more information, see
   :ref:`classof-contract`.

   The argument to ``classof`` should always be an *ancestor* class because
   the implementation has logic to allow and optimize away
   upcasts/up-``isa<>``'s automatically. It is as though every class
   ``Foo`` automatically has a ``classof`` like:

   .. code-block:: c++

      class Foo {
        [...]
        template <class T>
        static bool classof(const T *,
                            ::llvm::enable_if_c<
                              ::llvm::is_base_of<Foo, T>::value
                            >::type* = 0) { return true; }
        [...]
      };

   Note that this is the reason that we did not need to introduce a
   ``classof`` into ``Shape``: all relevant classes derive from ``Shape``,
   and ``Shape`` itself is abstract (has no entry in the ``Kind`` enum),
   so this notional inferred ``classof`` is all we need. See `Concrete
   Bases and Deeper Hierarchies`_ for more information about how to extend
   this example to more general hierarchies.

Although for this small example setting up LLVM-style RTTI seems like a lot
of "boilerplate", if your classes are doing anything interesting then this
will end up being a tiny fraction of the code.

Concrete Bases and Deeper Hierarchies
=====================================

For concrete bases (i.e. non-abstract interior nodes of the inheritance
tree), the ``Kind`` check inside ``classof`` needs to be a bit more
complicated. The situation differs from the example above in that

* Since the class is concrete, it must itself have an entry in the ``Kind``
  enum because it is possible to have objects with this class as a dynamic
  type.

* Since the class has children, the check inside ``classof`` must take them
  into account.

Say that ``SpecialSquare`` and ``OtherSpecialSquare`` derive
from ``Square``, and so ``ShapeKind`` becomes:

.. code-block:: c++

    enum ShapeKind {
      SK_Square,
   +  SK_SpecialSquare,
   +  SK_OtherSpecialSquare,
      SK_Circle
    }

Then in ``Square``, we would need to modify the ``classof`` like so:

.. code-block:: c++

   -  static bool classof(const Shape *S) {
   -    return S->getKind() == SK_Square;
   -  }
   +  static bool classof(const Shape *S) {
   +    return S->getKind() >= SK_Square &&
   +           S->getKind() <= SK_OtherSpecialSquare;
   +  }

The reason that we need to test a range like this instead of just equality
is that both ``SpecialSquare`` and ``OtherSpecialSquare`` "is-a"
``Square``, and so ``classof`` needs to return ``true`` for them.

This approach can be made to scale to arbitrarily deep hierarchies. The
trick is that you arrange the enum values so that they correspond to a
preorder traversal of the class hierarchy tree. With that arrangement, all
subclass tests can be done with two comparisons as shown above. If you just
list the class hierarchy like a list of bullet points, you'll get the
ordering right::

   | Shape
     | Square
       | SpecialSquare
       | OtherSpecialSquare
     | Circle

.. _classof-contract:

The Contract of ``classof``
---------------------------

To be more precise, let ``classof`` be inside a class ``C``.  Then the
contract for ``classof`` is "return ``true`` if the dynamic type of the
argument is-a ``C``".  As long as your implementation fulfills this
contract, you can tweak and optimize it as much as you want.

.. TODO::

   Touch on some of the more advanced features, like ``isa_impl`` and
   ``simplify_type``. However, those two need reference documentation in
   the form of doxygen comments as well. We need the doxygen so that we can
   say "for full details, see http://llvm.org/doxygen/..."

Rules of Thumb
==============

#. The ``Kind`` enum should have one entry per concrete class, ordered
   according to a preorder traversal of the inheritance tree.
#. The argument to ``classof`` should be a ``const Base *``, where ``Base``
   is some ancestor in the inheritance hierarchy. The argument should
   *never* be a derived class or the class itself: the template machinery
   for ``isa<>`` already handles this case and optimizes it.
#. For each class in the hierarchy that has no children, implement a
   ``classof`` that checks only against its ``Kind``.
#. For each class in the hierarchy that has children, implement a
   ``classof`` that checks a range of the first child's ``Kind`` and the
   last child's ``Kind``.
