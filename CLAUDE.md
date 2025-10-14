# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal website and resume for Simon Nordberg, built with Jekyll and hosted on GitHub Pages. The site features a clean, minimal design with a focus on the resume page that includes detailed work experience, entrepreneurship history, and education.

## Architecture

### Static Site Generation
- **Jekyll 3.x** with GitHub Pages compatibility
- **Liquid templating** for layouts and includes
- Front matter in markdown files defines page metadata (layout, title, permalink, class)

### Layouts
- `_layouts/default.html`: Main layout with header (avatar + name) and footer
- `_layouts/simple.html`: Minimal centered layout for simple pages
- `_layouts/post.html`: Blog post layout (if used)

### Content Structure
- `index.md`: Homepage with "simple" layout
- `resume.md`: Full resume page with custom grid-based layout, detailed experience sections, and PDF download link
- `404.md`: Error page
- Resume content is HTML embedded in markdown for precise layout control

### Styling
- `assets/css/style.scss`: Single SCSS file containing all styles
- Uses CSS Grid for responsive two-column layouts (1:1.618 golden ratio)
- Company logos displayed via CSS background images on experience articles
- Print styles included for PDF generation
- Color scheme: Red accent (#cc3232) on white background
- Typography: Lato (body), IBM Plex Serif (headings)

### Assets
- Company logos: `/assets/{company-name}.png` (referenced in SCSS)
- Resume PDF: `/assets/simonnordberg-resume.pdf`
- Favicon set in `/assets/favicon/`
- Avatar: `/assets/avatar.jpg`

## Development Commands

### Local Development (Docker - Recommended)
```bash
docker compose up
```
Site will be available at `http://localhost:4000`

### Local Development (Native Ruby)
If you have Ruby and Bundler installed locally:
```bash
bundle install
bundle exec jekyll serve --host 0.0.0.0 --port 4000
```

### Build Static Site
```bash
bundle exec jekyll build
```
Output goes to `_site/` directory (gitignored)

## Content Editing

### Resume Updates
The resume content is in `resume.md`. It uses:
- Grid-based layout with `.grid-container` and `.grid-item` classes
- Experience articles with company-specific CSS classes (e.g., `experience spotify`)
- Company logos are automatically displayed via CSS background images matching the class name

To add a new company experience:
1. Add entry in `resume.md` with appropriate article class (e.g., `class="experience newcompany"`)
2. Add logo as `/assets/newcompany.png`
3. Add CSS rule in `assets/css/style.scss` under the resume article section:
   ```scss
   &.newcompany > header {
     background-image: url('/assets/newcompany.png');
   }
   ```

### Resume PDF
Update the PDF file at `/assets/simonnordberg-resume.pdf` when resume content changes. The PDF is linked from the resume page download button.

## Deployment

This site is deployed to GitHub Pages. Any push to the `main` branch will trigger a rebuild and deployment automatically. No manual build or deployment steps are required.

## Configuration

- `_config.yml`: Jekyll configuration including site title, URL, social links, and defaults
- `CNAME`: Custom domain configuration for GitHub Pages
- `.gitignore`: Excludes `_site/` and Jekyll cache directories
