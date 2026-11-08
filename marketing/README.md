# Marketing materials — Family To-Do for E-Paper 1.0

| File | Use |
|------|-----|
| `linkedin_article.md` | LinkedIn article (Write article → paste) |
| `article/article.html` | The same article, ready to copy from a browser, with the images in place |
| `article/00_cover.png` … `04_display.png` | Article cover (1920×1080) and inline images |
| `linkedin_post.md` | LinkedIn feed post, plus the first comment with links |
| `images/linkedin_post_1080x1350.png` | Image for the post (4:5 portrait, takes the most space in the feed) |
| `images/linkedin_article_cover_1920x1080.png` | Article cover image |
| `make_graphics.sh` | Regenerates all images from `../release_apple_store/screenshots/1320x2868/en/` (and `photos/display.jpg`, if present) |

## Before publishing

- [ ] App Store link: replace `<APP_STORE_LINK>` in both texts once the app is approved
- [ ] Add a photo of the real display as `photos/display.jpg` (landscape, about 1600×1000 or larger) and run `./make_graphics.sh`. The hardware is the most interesting part of the story, so a real photo is strongly recommended.
- [ ] After publishing the article, put its link in the post's first comment (`<ARTICLE_LINK>`)
- [ ] Optional: add a sentence about the tools you used to build it (e.g. AI-assisted development), if you want to show that skill too

## Suggested order

1. Publish the article first.
2. Two or three days later, publish the post with the image, and the links in the first comment.

Requires ImageMagick 7 (`brew install imagemagick`).
