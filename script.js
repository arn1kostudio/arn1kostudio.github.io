const yearNode = document.getElementById("year");
if (yearNode) {
  yearNode.textContent = new Date().getFullYear().toString();
}

function initAnchorScroll() {
  const header = document.querySelector(".site-header");
  const links = document.querySelectorAll('a[href^="#"]');
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let scrollFrame = 0;

  function targetTop(target) {
    const headerOffset = header ? header.getBoundingClientRect().height + 20 : 20;
    return Math.max(0, window.scrollY + target.getBoundingClientRect().top - headerOffset);
  }

  function animateScroll(top) {
    if (prefersReducedMotion.matches) {
      window.scrollTo({ top, left: 0, behavior: "auto" });
      return;
    }

    const start = window.scrollY;
    const distance = top - start;
    const duration = Math.min(520, Math.max(260, Math.abs(distance) * 0.22));
    const startedAt = performance.now();

    window.cancelAnimationFrame(scrollFrame);

    function step(now) {
      const progress = Math.min(1, (now - startedAt) / duration);
      const eased = 1 - Math.pow(1 - progress, 3);
      window.scrollTo(0, start + distance * eased);

      if (progress < 1) {
        scrollFrame = window.requestAnimationFrame(step);
      }
    }

    scrollFrame = window.requestAnimationFrame(step);
  }

  for (const link of links) {
    link.addEventListener("click", (event) => {
      const { hash } = link;
      if (!hash || hash === "#") {
        return;
      }

      const target = document.querySelector(hash);
      if (!target) {
        return;
      }

      event.preventDefault();
      history.replaceState(null, "", hash);
      animateScroll(targetTop(target));
    });
  }
}

const revealItems = document.querySelectorAll(".app-card, .phone-shot, .glass-panel, .principles article, .contact-card, .spec-card, .mini-gallery img, .app-detail-hero");

initAnchorScroll();

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.16 }
  );

  for (const item of revealItems) {
    item.classList.add("reveal");
    observer.observe(item);
  }
} else {
  for (const item of revealItems) {
    item.classList.add("is-visible");
  }
}
