CREATE TABLE "users" (
    "id" SERIAL PRIMARY KEY,
    "username" VARCHAR(25) UNIQUE NOT NULL,
    "last_login" TIMESTAMP DEFAULT NOW(),
    CONSTRAINT "username_not_empty" CHECK (TRIM("username") != '')
);
CREATE INDEX "login_index" ON "users" ("last_login");

CREATE TABLE "topics" (
    "id" SERIAL PRIMARY KEY,
    "name" VARCHAR(30) UNIQUE NOT NULL,
    "description" VARCHAR(500),
    CHECK (TRIM("name") != '')
);

CREATE TABLE "posts" (
    "id" SERIAL PRIMARY KEY,
    "topic_id" INT REFERENCES "topics" ON DELETE CASCADE,
    "user_id" INT REFERENCES "users" ON DELETE SET NULL,
    "created_at" TIMESTAMP DEFAULT NOW(),
    "title" VARCHAR(100) NOT NULL,
    "url" TEXT,
    "text_content" TEXT,
    CHECK (TRIM("title") != ''),
    CONSTRAINT "url_or_text_exclusive" CHECK (
        NOT("url" IS NULL AND "text_content" IS NULL) AND
        NOT("url" IS NOT NULL AND "text_content" IS NOT NULL)
    )
);
CREATE INDEX "topic_index" ON "posts" ("topic_id");
CREATE INDEX "user_index" ON "posts" ("user_id");
CREATE INDEX "url_index" ON "posts" ("url");

CREATE TABLE "comments" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INT REFERENCES "users" ON DELETE SET NULL,
    "post_id" INT REFERENCES "posts" ON DELETE CASCADE,
    "comment_id" INT REFERENCES "comments" ON DELETE CASCADE,
    "created_at" TIMESTAMP DEFAULT NOW(),
    "content" TEXT NOT NULL,
    CHECK (TRIM("content") != '')
);
CREATE INDEX "parent_index" ON "comments" ("comment_id");
CREATE INDEX "created_index" ON "comments" ("created_at");

CREATE TABLE "user_post_votes" (
    "user_id" INT REFERENCES "users" ON DELETE SET NULL,
    "post_id" INT REFERENCES "posts" ON DELETE CASCADE,
    "value" SMALLINT,
    PRIMARY KEY ("user_id", "post_id"),
    CONSTRAINT "value_is_1/-1" CHECK ("value" = 1 OR "value" = -1)
);
CREATE INDEX "post_index" ON "user_post_votes" ("post_id");

INSERT INTO "users" ("username")
    SELECT "username" FROM "bad_posts"
    UNION
    SELECT "username" FROM "bad_comments"
    UNION
    SELECT regexp_split_to_table("upvotes", ',') FROM "bad_posts"
    UNION
    SELECT regexp_split_to_table("downvotes", ',') FROM "bad_posts";

INSERT INTO "topics" ("name")
    SELECT DISTINCT "topic" FROM "bad_posts";

INSERT INTO "posts" ("topic_id", "user_id", "title", "url", "text_content")
    SELECT "t"."id" "topic_id", "u"."id" "user_id",
        CASE WHEN LENGTH("p"."title") > 100 THEN LEFT("p"."title", 100)
            ELSE "p"."title" END AS "title",
        "p"."url", "p"."text_content"
    FROM "bad_posts" "p"
    JOIN "topics" "t" ON "p"."topic" = "t"."name"
    JOIN "users" "u" ON "p"."username" = "u"."username";
    
INSERT INTO "comments" ("user_id", "post_id", "content")
    SELECT "u"."id" "user_id", "c"."post_id", "c"."text_content"
    FROM "bad_comments" "c"
    JOIN "users" "u" ON "u"."username" = "c"."username";
    
INSERT INTO "user_post_votes" ("user_id", "post_id", "value")
    WITH t1 AS (
        SELECT "id" "post_id", regexp_split_to_table("upvotes", ',')"username", 1 AS "vote"
        FROM "bad_posts"
        UNION
        SELECT "id" "post_id", regexp_split_to_table("downvotes", ',') "username", -1 AS "vote"
        FROM "bad_posts"
    )
    SELECT "u"."id" "user_id", "post_id", "vote" FROM t1
    JOIN "users" "u" ON "u"."username" = "t1"."username"
    ORDER BY "user_id", "post_id";
