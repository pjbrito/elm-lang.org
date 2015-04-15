import Graphics.Element exposing (..)
import Markdown
import Website.Skeleton exposing (skeleton)
import Website.Tiles as Tile
import Window

port title : String
port title = "Elm 0.15"


main =
  Signal.map (skeleton "Blog" everything) Window.dimensions


everything wid =
  let w = min 600 wid
  in
    flow down
      [ width w content
      ]

content = Markdown.toElement """

<h1><div style="text-align:center">Elm 0.15
<div style="padding-top:4px;font-size:0.5em;font-weight:normal">Asynchrony with Tasks</div></div>
</h1>

<span style="color:red;">DRAFT - NOT FOR DISTRIBUTION</span>

This release introduces **tasks**, a way to define complex asynchronous
operations. Similar to [C#&rsquo;s tasks][csharp] and [JavaScript&rsquo;s
promises][promise], it makes it simple to describe long-running effects and
keep things responsive. It also provides a way to wrap up tons of browser APIs
in Elm.

[csharp]: https://msdn.microsoft.com/en-us/library/hh191443.aspx
[promise]: http://www.html5rocks.com/en/tutorials/es6/promises/

Thanks to tasks, we have a couple new packages that make practical development
easier:

  * [elm-http][] &mdash; get JSON and strings from servers with a nice high-level API.
  * [elm-history][] &mdash; easily navigate browser history from Elm
  * [elm-router][] &mdash; generate pages dynamically based on the URL

[elm-http]: http://package.elm-lang.org/packages/evancz/elm-http/latest/
[elm-history]: https://github.com/TheSeamau5/elm-history/
[elm-router]: https://github.com/TheSeamau5/elm-router/

Knowing the monstrosity that is XMLHttpRequest, it is really great to see that
functionality exposed in [elm-http][] without the atrocious parts. In any case,
this is just the start! In the next weeks and months, the community is going to
be filling in a lot of gaps by creating libraries for APIs like local storage,
geolocation, dropbox.js, firebase, etc. etc.

This release also marks a milestone for Elm in the sense that the fundamentals
are pretty much worked out. As soon as this release goes out, we are going to
begin focusing on improving documentation and making our testing tools great.
We expect we will have one or two more releases before 1.0 to polish syntax and
core libraries based on real-world usage of tasks.


## Motivation

Since the release of [elm-html][], we have seen more and more people writing
practical web apps in Elm. [Richard Feldman](https://twitter.com/rtfeldman)
recently rewrote his writing app [Dreamwriter](https://dreamwriter.io/) from
[React and CoffeeScript](https://github.com/rtfeldman/dreamwriter-coffee/tree/strangeloop)
to [Elm and CoffeeScript](https://github.com/rtfeldman/dreamwriter/tree/strangeloop),
which has been a very interesting case study.

[elm-html]: /blog/Blazing-Fast-Html.elm

Richard took the approach of rewriting the core of Dreamwriter in Elm, and then
slowly expanding that core to cover as much as possible. This means he was able
to switch over gradually, and leave things in CoffeeScript if they were
working fine. We have noticed a couple really nice benefits so far:

  * The bugs and crashes are always coming from the CoffeeScript code. **The
    Elm code just does not cause runtime errors in practice.**

  * **Refactoring is super easy in the Elm section.** In JS or CoffeeScript,
    changing a function name or changing a data representation usually causes
    a cascade of changes that are quite hard to track down, even when you have
    great test coverage. In Elm, you can be confident that the compiler will
    tell you *all* the places that need to be updated as a result of your
    changes. Richard can change stuff in Elm and be shockingly confident that
    it will not quietly break some seemingly unrelated feature.

  * **Rendering is extremely fast.** [elm-html][] makes it really simple to
    optimize by just sprinkling [`lazy`][lazy] into your rendering code.

[lazy]: http://package.elm-lang.org/packages/evancz/elm-html/latest/Html-Lazy

So Richard's question to me is &ldquo;how can we write more in Elm?&rdquo; Most
of his bugs and hard to refactor code is in CoffeeScript. For him, he will have
a better code base if he can move even more code into Elm. This release is
answering the question &ldquo;how can we write more in Elm and *keep* all the
great benefits that make it worthwhile to use Elm in the first place?&rdquo;


## Tasks

The biggest part of this release is introducing **tasks**. Tasks make it easy
to describe asynchronous operations that may fail, like HTTP requests or
writing to a database. Tasks also work like light-weight threads in Elm, so
you can have a bunch running at the same time and the [runtime][rts] will hop
between them if they are blocked. As a simple example, let’s get the README
for Elm&rsquo;s core libraries from the
[Elm Package Catalog](http://package.elm-lang.org/).

[rts]: http://en.wikipedia.org/wiki/Runtime_system

```haskell
import Http

pkgUrl =
  "http://package.elm-lang.org/packages/elm-lang/core/latest/README.md"

getReadme : Task Http.Error String
getReadme =
  Http.getString pkgUrl
```

So `getReadme` is a `Task` that can be performed by Elm&rsquo;s runtime. When
we run the task, it will either fail with an [`Http.Error`][error] or succeed
with a string of markdown.

[error]: http://package.elm-lang.org/packages/evancz/elm-http/latest/Http#Error

To actually perform a task, you send it out a [port][]. Currently Richard sends
certain values out to CoffeeScript which performs all sorts of effects and then
lets Elm know about it once they are done. That means some logic ends up in
CoffeeScript. Tasks let you describe all that logic in Elm, so Richard can
describe the whole task in Elm and send it to Elm&rsquo;s runtime which will
go through and make it all happen. The end result is the same, but now Richard
has a code base that is easier to refactor and debug!

To learn more about tasks, check out [the tutorial](/learn/Tasks.elm)!


## Faster Text Rendering

One of our commercial users, [CircuitHub](https://www.circuithub.com/), has
been using collages to render complex circuits. The performance bottleneck
for them was text rendering, so thanks to
[James Smith](https://github.com/jazmit), we added a simple function that let
us render to canvas much more efficiently:

```haskell
Graphics.Collage.text : Text -> Form
```

We get to reuse the whole [`Text`](http://package.elm-lang.org/packages/elm-lang/core/latest/Text)
API but we then render direct to canvas to get much better performance. I am
looking forward to seeing this used in practice!

As part of this change, we moved a few functions out of the `Text` library to
clean up the API. Here is a rough listing of stuff that has moved into the
`Graphics.Element` library:

```haskell
leftAligned : Text -> Element
centered : Text -> Element
rightAligned : Text -> Element

show : a -> Element   -- was Text.asText
```

The goal here is to make `Text` an abstract representation that can be rendered
in many different contexts. Sometimes you render with `Graphics.Collage`,
sometimes with `Graphics.Element`, but that should be handled by *those*
libraries.

Keep an eye out for this when you are upgrading! You will need to mess with any
uses of `leftAligned` to get everything working. In the process of upgrading
this website to Elm 0.15 I found this often reduced the number of imports I
needed by quite a lot, especially in smaller beginner examples that used
`asText`.


## Towards &ldquo;No Runtime Exceptions&rdquo;

We are currently at a point where you *practically* never get runtime
exceptions in Elm. I mean, you can do it, but you have to try really hard.

That said, there are a few historical relics in the `List` library that *can*
cause a crash if they are given an empty list. Stuff like `head` and `tail` are
pretty easy to run into if you are a beginner. This is primarily because older
languages in the tradition of Elm made this choice and it felt weird to diverge,
especially when Elm was younger. This release replaces these cases with
functions that give back a `Maybe` and sets us up for avoiding unintended
runtime exceptions *entirely*.

So the new `List` library looks like this:

```haskell
head : List a -> Maybe a
tail : List a -> Maybe (List a)

maximum : List comparable -> Maybe comparable
minimum : List comparable -> Maybe comparable
```

We are thinking of adding two functions to `Maybe` in a later release to help
make it really pleasant to *always* return a `Maybe` when a function may fail.
The first one is just an alias for `withDefault` which would work like this:

```haskell
(?) : Maybe a -> a -> a

firstNumber =
    head numberList ? 0
```

If you want to get the head of a list of numbers *or* just go with zero if it
is empty. This is really cool, but (1) we are worried about adding too many infix
operators and (2) we are not sure exactly what precedence this operator should
have. If we see people complaining about it being a pain to work with functions
that return maybes, that will be good evidence that we should add `(?)` to the
standard libraries.

The second function is a lot more questionable:

```haskell
unsafe : Maybe a -> a

firstNumber =
    unsafe (head numberList)
```

The `unsafe` function extracts a value or crashes. But why? There are a tiny
set of cases where you *know* it is going to be fine and might want this.
For example, imagine you have a `Dict` and the values are lists. You would
never put an empty list in your dictionary, that would be silly, so you know
you can always get elements of the list. I have seen this a few times
programming in languages like Elm, and the `unsafe` function makes the risks
extremely explicit. You can search through code for any occurances of `unsafe`
and quickly identify any risks. It also is a good sign of &ldquo;maybe you
should try to say the same thing a different way?&rdquo; In any case, this
feels similar in spirit to [`Debug.crash`][crash] which also makes risks very
obvious.

[crash]: http://package.elm-lang.org/packages/elm-lang/core/latest/Debug#crash

So for those of you using Elm, please define these functions yourself for now
and tell us how it goes! Do you need them? Are they generally bad? Do you have
some good examples of when they are handy? I don't want to add these things to
the standard libraries lightly, so share your evidence with us!


## Import Syntax

We dramatically reduced the set of default imports in 0.14. This was &ldquo;the
right thing to do&rdquo; but it made our existing import syntax feel a bit
clunky. You needed a pretty big chunk of imports to get even basic programs
running. This release introduces improved syntax that will let you cut a
bunch of lines from your import section. As a brief preview, let&rsquo;s look
at the two extremes of the syntax. First we have the plain old import:

```haskell
import Http
```

With this, we can refer to any value in the `Http` module as `Http.get`
or `Http.post`. Using qualified names like this is recommended, so this
should cover most typical cases. Sometimes you want to go crazy though, so on
the other end of the spectrum, we have a way to choose a shorter prefix with
`as` and a way to directly expose some values with `exposing`.

```haskell
import Html.Attributes as Attr exposing (..)
```

In this case we decided to expose *everything* in `Html.Attributes` so we can
just say things like [`id`][id] and [`href`][href] directly. We also
locally rename the module to `Attr` so if there is ever a name collision, we
can say [`Attr.width`][width] to make it unambiguous. You can read more about
this [here](/learn/Modules.elm).

[id]: http://package.elm-lang.org/packages/evancz/elm-html/latest/Html-Attributes#id
[href]: http://package.elm-lang.org/packages/evancz/elm-html/latest/Html-Attributes#href
[width]: http://package.elm-lang.org/packages/evancz/elm-html/latest/Html-Attributes#width

This seems like a tiny change, but it has made a huge difference in how it
feels to work with imports. I have been really happy with it so far. When you
are upgrading your code, keep an eye out for:

  * Needing to add `exposing` keyword.
  * Importing the same module on two lines. This can now be reduced to one line.
  * Importing [default modules](https://github.com/elm-lang/core#default-imports).
    They come in by default, so there is no need to explicitly import `Signal`
    or `List` unless you are doing something special. (We are planning to add
    warnings for this in a future release to make this easier!)


## Introducing Mailboxes

[The Elm Architecture][arch] is all about creating nestable and reusable
components. In 0.14 this meant using channels and the [local-channel][]
package. The terminology and API were kind of messy because parts of it evolved
*after* 0.14 came out, making things seem artificially complex. So with 0.15
we are revamping this whole API so that it is centralized and easier to learn.

[arch]: https://github.com/evancz/elm-architecture-tutorial/#the-elm-architecture
[local-channel]: http://package.elm-lang.org/packages/evancz/local-channel/latest

The new `Signal` library introduces the concept of a `Mailbox`.

```haskell
type alias Mailbox =
    { address : Address a
    , signal : Signal a
    }
```

A mailbox has two key parts: (1) an address that you can send messages to and
(2) a signal that updates whenever a message is received. This means you can
have `onClick` handlers in your HTML report to a particular address, thus
feeding values back into your program as a signal.

There are two ways to talk to a particular mailbox. The first is to just send
a message.

```haskell
send : Address a -> a -> Task x ()
```

You provide an address and a value to send, and when the task is performed,
that value shows up at the corresponding mailbox. It&rsquo;s kinda like real
mailboxes! The second way is to create a message that *someone else* can send.

```haskell
message : Address a -> a -> Message
```

In this case, we just create a message. It has an address and it has a
value, but like an envelope in real life, someone still needs to send it!
We use this with functions like `onClick` and `onBlur` from
[`Html.Events`][events] so that they can send the `Message` at the appropriate
time.

[events]: http://package.elm-lang.org/packages/evancz/elm-html/latest/Html-Events

We should have some tutorials coming that do a better job explaining what is
going on with mailboxes and why they are important! For those of you with 0.14
code to upgrade, first take a look at [the whole API][mailbox] to get a feel
for it. The core concepts are pretty much the same, so the changes are mostly
find and replace:

[mailbox]: http://45.55.164.161:8000/packages/elm-lang/core/2.0.0/Signal#Mailbox

  * `Signal.Channel` becomes `Signal.Mailbox` in your types
  * `Signal.channel` becomes `Signal.mailbox` when creating mailboxes
  * `Signal.send` becomes `Signal.message` in your event handlers
  * `(Signal.subscribe channel)` becomes `mailbox.signal`
  * Any talk of `LocalChannel` is replaced by `Address` and [`forwardTo`][forwardTo]

[forwardTo]: http://package.elm-lang.org/packages/elm-lang/core/latest/Signal#forwardTo


## Thank you

More so than normal, this release went through a pretty crazy design and
exploration phase, so I want to give a huge thank you to everyone who was part
of that process. I think we put together a ton of great ideas that will make
their way into Elm soon enough!

[list]: https://groups.google.com/forum/#!forum/elm-discuss

Thank you to [Elm User Group SF](http://www.meetup.com/Elm-user-group-SF/)
which worked with some pre-release versions of 0.15 to vet the tasks API and
start making some new packages for browser APIs.

"""






