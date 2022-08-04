--1a
CREATE TABLE "users"
    (
        "id"            SERIAL    PRIMARY KEY,
        "username"      VARCHAR(25)
            UNIQUE NOT NULL CHECK (LENGTH(TRIM("username")) > 0),
        "creation_date" DATE      NOT NULL
            DEFAULT CURRENT_DATE,
        "last_login"    TIMESTAMP NOT NULL
            DEFAULT CURRENT_TIMESTAMP
    );

--1b
CREATE TABLE "topics"
    (
        "id"                 SERIAL    PRIMARY KEY,
        "topic_name"         VARCHAR(30)
            UNIQUE NOT NULL CHECK (LENGTH(TRIM("topic_name")) > 0),
        "description"        VARCHAR(500)
            DEFAULT NULL,
        "creation_date_time" timestamp NOT NULL
            DEFAULT CURRENT_TIMESTAMP
    );

-- 1c
CREATE TABLE "posts"
    (
        "id"            SERIAL    PRIMARY KEY,
        "title"         VARCHAR(100)
            UNIQUE CHECK (LENGTH(TRIM("title")) > 0),
        "url"           VARCHAR(500)
            DEFAULT NULL,
        "text_content"  TEXT
            DEFAULT NULL,
        "topic_id"      BIGINT    NOT NULL
            REFERENCES "topics" ON DELETE CASCADE,
        "user_id"       BIGINT
            REFERENCES "users" ON DELETE SET NULL,
        "creation_time" timestamp NOT NULL
            DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "url_or_text" CHECK ("url" IS NOT NULL
                                        OR "text_content" IS NOT NULL
                                       )
    );
CREATE TABLE "comments"
    (
        "id"                SERIAL    PRIMARY KEY,
        "user_id"           BIGINT
            REFERENCES "users" ON DELETE SET NULL,
        "post_id"           BIGINT    NOT NULL
            REFERENCES "posts" ON DELETE CASCADE,
        "text_content"      TEXT      NOT NULL CHECK (LENGTH(TRIM("text_content")) > 0),
        "creation_time"     timestamp NOT NULL
            DEFAULT CURRENT_TIMESTAMP,
        "parent_comment_id" BIGINT
            REFERENCES "comments" ("id") ON DELETE CASCADE
    );
CREATE TABLE "votes"
    (
        "id"      SERIAL   PRIMARY KEY,
        "user_id" BIGINT
            REFERENCES "users" ON DELETE SET NULL,
        "post_id" BIGINT   NOT NULL
            REFERENCES "posts" ON DELETE CASCADE,
        "vote"    SMALLINT CHECK ("vote" = 1
                                  OR "vote" = -1
                                 ),
        CONSTRAINT "unique_vote"
            UNIQUE ("post_id", "user_id")
    );

-- users table
CREATE INDEX "last_login"
    ON "users" ("last_login");

-- posts table 
--e
--e
CREATE INDEX "posts_title_index" 
    ON "posts" ("title" VARCHAR_PATTERN_OPS);
--f
CREATE INDEX "posts_topicid_index"
    ON "posts" ("topic_id");
--b, g
CREATE INDEX "posts_userid_index"
    ON "posts" ("user_id");
--h
CREATE INDEX "posts_url_index"
    ON "posts" ("url");

--comments table
--i
CREATE INDEX "comments_parentid_index"
    ON "comments" ("parent_comment_id");
--k
CREATE INDEX "comments_userid_index"
    ON "comments" ("user_id");
-- votes table
CREATE INDEX "vote_postid_index"
    ON "votes" ("post_id", "vote");
CREATE INDEX "votes_userid_index"
    ON "votes" ("user_id");

---MIGRATE DATA 

--migrate to users table
-- need all unique users
INSERT INTO "users"
    (
        "username"
    )
            SELECT DISTINCT
                "username"
            FROM
                bad_posts
            UNION
            SELECT DISTINCT
                "username"
            FROM
                bad_comments
            UNION
            SELECT DISTINCT
                Regexp_split_to_table("downvotes", ',') AS username
            FROM
                bad_posts
            UNION
            SELECT DISTINCT
                Regexp_split_to_table("upvotes", ',') AS username
            FROM
                bad_posts;

--migrate to topics table
-- all unique topics
INSERT INTO "topics"
    (
        "topic_name"
    )
            SELECT DISTINCT
                "topic"
            FROM
                "bad_posts";

--migrate into posts table (truncate title to 100 characters)
INSERT INTO "posts"
    (
        "title",
        "url",
        "text_content",
        "topic_id",
        "user_id"
    )
            SELECT
                LEFT("bp"."title", 100),
                "bp"."url",
                "bp"."text_content",
                "t"."id",
                "u"."id"
            FROM
                bad_posts  "bp"
                JOIN
                    topics "t"
                        ON "bp"."topic" = "t"."topic_name"
                JOIN
                    users  "u"
                        ON "bp"."username" = "u"."username";

--Migrate into comments table
--REMOVE NOT NULL IN parent_id to allow insertion 
INSERT INTO "comments"
    (
        "user_id",
        "post_id",
        "text_content"
    )
            SELECT
                "u"."id",
                "p"."id",
                "bc"."text_content"
            FROM
                bad_comments "bc"
                INNER JOIN
                    users    "u"
                        ON "bc"."username" = "u"."username"
                INNER JOIN
                    posts    "p"
                        ON "p"."id" = "bc"."post_id";

--Migrate into votes table
INSERT INTO "votes"
    (
        "user_id",
        "post_id",
        vote
    )
            SELECT
                "u"."id",
                "t1"."id",
                1 as "upvote"
            FROM
                (
                    SELECT
                        "id",
                        regexp_split_to_table(upvotes, ',') AS "up_vote"
                    FROM
                        bad_posts
                )         t1
                JOIN
                    users "u"
                        ON "u"."username" = "t1"."up_vote";
INSERT INTO "votes"
    (
        "user_id",
        "post_id",
        vote
    )
            SELECT
                "u"."id",
                "t1"."id",
                -1 as "downvote"
            FROM
                (
                    SELECT
                        "id",
                        regexp_split_to_table(downvotes, ',') AS "down_vote"
                    FROM
                        bad_posts
                )         t1
                JOIN
                    users "u"
                        ON "u"."username" = "t1"."down_vote";

--some tests
---List all topics that don’t have any posts

SELECT
    t.topic_name
FROM
    topics t
WHERE
    t.topic_name NOT IN (
                            SELECT
                                t.topic_name
                            FROM
                                topics    t
                                LEFT JOIN
                                    posts p
                                        ON t.id = p.topic_id
                        );

-- answer all topics (89 in total) actually have posts in this data set

--List the latest 20 posts for a given topic
--eg topic Applications 


SELECT
    p.title
from
    posts      p
    LEFT JOIN
        topics t
            ON t.id = p.topic_id
WHERE
    t.topic_name LIKE '%Applications%'
ORDER BY
    creation_time DESC
LIMIT 20;

-- List the latest 20 posts made by a given user. 

SELECT
    p.title
from
    posts     p
    LEFT JOIN
        users u
            ON u.id = p.user_id
WHERE
    u.username LIKE '%Gus32%'
ORDER BY
    creation_time DESC;