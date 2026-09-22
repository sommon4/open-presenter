// Keeps the newest Open Ended response card in view when auto-scroll is on,
// and pops new cards in.
const OpenEndedScroll = {
  mounted() {
    this.count = parseInt(this.el.dataset.count || "0", 10);
    this.scrollIfNeeded();
  },
  updated() {
    const count = parseInt(this.el.dataset.count || "0", 10);
    if (count > this.count) {
      const cards = this.el.querySelectorAll(".open-ended-card");
      const last = cards[cards.length - 1];
      if (last) last.classList.add("animate__animated", "animate__zoomIn");
      this.scrollIfNeeded();
    }
    this.count = count;
  },
  scrollIfNeeded() {
    if (this.el.dataset.autoScroll === "true") {
      this.el.scrollTo({ top: this.el.scrollHeight, behavior: "smooth" });
    }
  },
};

export default OpenEndedScroll;
