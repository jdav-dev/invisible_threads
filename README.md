# Invisible Threads: Group email without the exposure

This is a submission for the
[Postmark Challenge: Inbox Innovators](https://dev.to/challenges/postmark).

## What I Built

[Invisible Threads](https://invisiblethreads.jdav.dev/) is a privacy-first group email solution.
As the organizer, you create a thread from a list of members' names and emails.  Members can reply
to the thread like any other email.  Replies are forwarded to all members using the thread's
original sender address.  Real email addresses stay hidden.

You can use temporary threads for one-off events.  For example, school fundraisers, sports
seasons, or volunteer events.  Or, you can keep a thread going indefinitely.

Every email includes `List-Unsubscribe` and `List-Unsubscribe-Post` headers, following
[Postmark's guidelines](https://postmarkapp.com/blog/list-unsubscribe-header).  Members can opt
out of individual threads with one click.  Organizers can close a thread at any time.  Closing a
thread stops all future messages.

## Demo

Try the demo app at <https://invisiblethreads.jdav.dev>.  You will need your own Postmark Server
API key!

## Code Repository

<https://github.com/jdav-dev/invisible_threads>

## How I Built It

Invisible Threads is built with [Elixir](https://elixir-lang.org/),
[Phoenix](https://www.phoenixframework.org/), and of course, [Postmark](https://postmarkapp.com/).
I had been wanting to experiment with the features that became Invisible Threads.  This contest
provided the perfect opportunity to sit down and figure them out.

The initial web app was created with Phoenix' code generators.  I then stripped it down to make
the demo as simple as possible.  Instead of a database, data is written to disk.  The default
authentication system was replaced with validating a Postmark API token.  A "user" in Invisible
Threads is one-to-one with a Postmark "server".

Keeping the infrastructure simple let me focus on new challenges.  I hadn't implemented emails
that reference each other before.  The `In-Reply-To` and `References` email headers did the trick.
I set the `Message-ID` header on the first email and then use that ID to tie the conversation
together.  It's easier to set the `Message-ID` than to fetch the value when Postmark sets it.

[Postmark's inbound email processing](https://postmarkapp.com/inbound-email) was a huge part of
this project.  Each recipient is provided with individual `Reply-To` addresses specific to each
thread.  The format is as follows:

```elixir
"#{postmark_hash}+#{thread_id}_#{recipient_id}@#{domain}"
```

For example:

```text
2288529e98a540d7a02e66448f3d9211+0e611a03-cfc6-4118-b71e-f03012cf1836_0447528b-36cc-45f9-ba9d-e5eab309772f@example.com
```

I was pleasantly surprised that Postmark allows so much data in the incoming address.

Every email includes `List-Unsubscribe` and `List-Unsubscribe-Post` headers, following
[Postmark's guidelines](https://postmarkapp.com/blog/list-unsubscribe-header).  Similar to the
inbound address, the unsubscribe links are specific to one recipient and thread.  This allows
recipients to leave individual threads when they choose.
