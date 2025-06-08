# Invisible Threads: Group email without the exposure

This is a submission for the
[Postmark Challenge: Inbox Innovators](https://dev.to/challenges/postmark).

## What I Built

[Invisible Threads](https://invisiblethreads.jdav.dev/) is a privacy-first group email solution.
As the organizer, you create a thread from members' names and emails. Members reply to the thread
like any other email. Replies are forwarded to all members using the thread's original sender
address. Real email addresses stay hidden.

You can use temporary threads for one-off events. For example, school fundraisers, sports seasons,
or volunteer events. You can also keep threads going indefinitely. Members can opt out of
individual threads with one click. Organizers can close a thread at any time. Closing a thread
stops all future messages.

## Demo

Follow these steps to use the demo. You will need a Postmark account.

1. Create a new "Live" server [in Postmark](https://account.postmarkapp.com/servers/new). Copy a
    "Server API token" for your new server.

    ![Postmark new server page](/priv/static/images/screenshots/create_server.png)

2. Visit <https://invisiblethreads.jdav.dev/users/log-in>, paste your API token, and click
    "Log in &#8594;".

    ![Invisible Threads login page](/priv/static/images/screenshots/login.png)

3. Click "+ New Thread" to create your first invisible thread.

    ![Invisible Threads index page](/priv/static/images/screenshots/threads_index.png)

4. Fill in "Sender Email Address" using a valid
    [Sender Signature](https://account.postmarkapp.com/signature_domains) from your Postmark
    account. "Email Thread Subject" sets the subject for all messages in the thread. Fill in name
    and email address for at least two members. Add more members as needed.

    ![New thread form](/priv/static/images/screenshots/new_thread.png)

5. Click "Create Thread". An introduction email will send to all members:

    > Hello Alice,
    >
    > You've been added to an invisible thread - a group email conversation where replies are shared with all participants, but email addresses stay hidden.
    >
    > Participants:
    >
    > - Alice (you)
    > - Bob
    >
    > Simply reply to this email as you normally would. Addresses stay private, but anything you include in your message (like a signature) will be visible to others.
    > For best results, reply from the same address that received this email. Reply STOP to unsubscribe.

6. Reply to the introduction email! Replies will forward to all other members.

7. When you're done with a thread, close it. Closing a thread will send the following email:

    > This invisible thread has been closed. No further messages will be delivered or shared.

    Individual members can unsubscribe from the thread. If their email client supports it,
    members can one-click unsubscribe. Alternatively, any reply starting with STOP, STOPALL,
    UNSUBSCRIBE, CANCEL, END, REVOKE, OPTOUT, or QUIT (case-insensitive) on a line by itself will
    unsubscribe the member. If all but one member unsubscribes, the thread is automatically
    closed.

    ![Closed thread with an unsubscribed participant](/priv/static/images/screenshots/closed_thread.png)

When you're done with the demo, feel free to delete your data, or keep using Invisible Threads if
you find it useful!

## Code Repository

<https://github.com/jdav-dev/invisible_threads>

## How I Built It

Invisible Threads is built with [Elixir](https://elixir-lang.org/),
[Phoenix](https://www.phoenixframework.org/), and most importantly,
[Postmark](https://postmarkapp.com/). Data lives on disk instead of a traditional database to keep
the demo light. Authentication uses Postmark API tokens, mapping each application user directly to
a Postmark server. The whole thing is deployed to [Fly.io](https://fly.io/). A minimal setup let
me focus on Postmark's offerings.

Threaded email conversations depend on specific headers. I set the `Message-ID` header on the
introduction email to a known value. On subsequent emails, I set the `In-Reply-To` and
`References` headers to the same message ID.

Emails go out with a `Reply-To` header pointing at
[Postmark's inbound email processing](https://postmarkapp.com/inbound-email). Postmark allows the
inbound email address to contain extra information after the mailbox. I used this space to give
each member a unique reply-to address per thread. The format looks like this:

```elixir
"#{postmark_mailbox}+#{thread_id}_#{member_id}@example.com"
```

Every email includes `List-Unsubscribe` and `List-Unsubscribe-Post` headers, following
[Postmark's guidelines](https://postmarkapp.com/blog/list-unsubscribe-header). Unsubscribe links
are unique to each member and thread.

I used Postmark's inbound email features three ways in this project.

1. To forward incoming email.
2. To automatically handle unsubscribe requests from email-based (mailto:) `List-Unsubscribe`
    headers.
3. To automatically unsubscribe members who reply with an opt-out keyword.

The first use case met my original idea going in. The second two use cases came up during
development. In all cases, Postmark's inbound email was a perfect fit!
