import { useState, useRef } from 'react'
import { motion, useScroll, useTransform, useSpring } from 'framer-motion'
import { Activity, Shield, Settings, BatteryCharging, Zap, Cpu } from 'lucide-react'
import './index.css'

function AccordionItem({ question, answer }) {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <div className="accordion-item">
      <button className={`accordion-header ${isOpen ? 'active' : ''}`} onClick={() => setIsOpen(!isOpen)}>
        {question}
        <span className="accordion-icon">+</span>
      </button>
      <div className="accordion-content">
        <p>{answer}</p>
      </div>
    </div>
  )
}

function App() {
  const { scrollYProgress: globalScroll } = useScroll()
  const stickyRef = useRef(null)

  // Make the mockup look like it's attached to the menu bar and sliding in slightly
  const mockupY = useTransform(globalScroll, [0, 0.2], [0, -50])
  const mockupScale = useTransform(globalScroll, [0, 0.2], [1, 0.95])
  const mockupScaleSpring = useSpring(mockupScale, { damping: 25, stiffness: 120 })

  // --- Sticky Section Animations (5 Steps) ---
  const { scrollYProgress: stickyScroll } = useScroll({
    target: stickyRef,
    offset: ["start start", "end end"]
  })

  // Text Blocks (5 blocks)
  // Set all resting Y positions to "-50%" combined with top: 50% in CSS for flawless dynamic centering
  // Box 1
  const text1Opacity = useTransform(stickyScroll, [0, 0.05, 0.15, 0.2], [0, 1, 1, 0])
  const text1Y = useTransform(stickyScroll, [0, 0.05, 0.15, 0.2], ["50%", "-50%", "-50%", "-150%"])

  // Box 2
  const text2Opacity = useTransform(stickyScroll, [0.2, 0.25, 0.35, 0.4], [0, 1, 1, 0])
  const text2Y = useTransform(stickyScroll, [0.2, 0.25, 0.35, 0.4], ["50%", "-50%", "-50%", "-150%"])

  // Box 3
  const text3Opacity = useTransform(stickyScroll, [0.4, 0.45, 0.55, 0.6], [0, 1, 1, 0])
  const text3Y = useTransform(stickyScroll, [0.4, 0.45, 0.55, 0.6], ["50%", "-50%", "-50%", "-150%"])

  // Box 4
  const text4Opacity = useTransform(stickyScroll, [0.6, 0.65, 0.75, 0.8], [0, 1, 1, 0])
  const text4Y = useTransform(stickyScroll, [0.6, 0.65, 0.75, 0.8], ["50%", "-50%", "-50%", "-150%"])

  // Final block (lower than box 4, lines up with Mac)
  // Explicitly map opacity to 1 at the end to ensure it absolutely does not fade out
  const text5Opacity = useTransform(stickyScroll, [0.8, 0.85, 1], [0, 1, 1])
  // Zero compromises perfectly settles at 95, relative to 25% top
  const text5Y = useTransform(stickyScroll, [0.8, 0.85, 0.9, 0.95, 1], [250, 95, 95, 95, 95])

  // The grand finale text fades in at the very end, AFTER the Macbook is done scaling
  const finalSubtitleOpacity = useTransform(stickyScroll, [0.95, 1], [0, 1])
  const finalSubtitleY = useTransform(stickyScroll, [0.95, 1], [30, 0])

  // MacBook Lid Animation: Starts almost completely closed (-88deg) so you see just a tiny sliver, opens to 0deg
  const macbookLidAngle = useTransform(stickyScroll, [0, 1], [-85.5, 0])

  // Scale the entire MacBook up before the final text appears
  const macbookScale = useTransform(stickyScroll, [0.9, 0.95], [1, 1.25])

  // The screen turns on (logo gets bright) as the lid opens! Starts completely off (0)
  const macbookLogoOpacity = useTransform(stickyScroll, [0, 0.3], [0, 1])

  // Fade out the 3D thickness edge as it opens so the corners don't stick out
  const lidEdgeOpacity = useTransform(stickyScroll, [0, 0.15], [1, 0])

  return (
    <>
      {/* Navigation */}
      <nav className="nav-container">
        <div className="nav-content">
          <div className="nav-logo" style={{ fontSize: '1.2rem', fontWeight: '700' }}>
            <div className="logo-icon" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', marginRight: '8px' }}>
              <Zap size={24} fill="white" color="white" />
            </div>
            Glide
          </div>

          <div className="nav-links">
            <a href="#features" onClick={(e) => {
              e.preventDefault();
              const el = document.querySelector('.sticky-features-section');
              if (el) {
                const rect = el.getBoundingClientRect();
                window.scrollTo({ top: window.scrollY + rect.top, behavior: 'smooth' });
              }
            }}>Features</a>
            <a href="#faq" onClick={(e) => {
              e.preventDefault();
              const el = document.querySelector('.faq-section');
              if (el) {
                const rect = el.getBoundingClientRect();
                window.scrollBy({ top: rect.top, behavior: 'instant' });
              }
            }}>FAQ</a>
            <a href="mailto:hello@glide-macos.app">Support</a>
          </div>

          <a href="https://github.com/abhiswrld/glide-macos/releases/latest/download/Glide.dmg" className="btn-primary btn-small">Download</a>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-container">
          <div className="hero-text-column">
            <h1 className="hero-title" style={{ marginBottom: '32px' }}>
              <span style={{ whiteSpace: 'nowrap' }}>A native macOS</span><br />
              <span>battery monitor.</span>
            </h1>

            <div className="hero-cta">
              <a href="https://github.com/abhiswrld/glide-macos/releases/latest/download/Glide.dmg" className="btn-primary btn-large">
                Download for Mac
              </a>
              <a href="https://github.com/abhiswrld/glide-macos" target="_blank" rel="noreferrer" className="btn-secondary">
                View Source
              </a>
            </div>

            <p className="hero-requirements hero-pill">
              macOS Sonoma or newer &middot; Mac with Apple Silicon required
            </p>

            <p className="hero-subtitle hero-pill">
              Zero CPU overhead. Precise telemetry. Advanced features like heat protection and MagSafe control, built directly on Apple's SMC.
            </p>
          </div>

          <div className="hero-visual-column">
            <motion.div className="hero-glass-container" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: "easeOut" }}>
              <img src="/hero-image.png" alt="Glide Interface" />
            </motion.div>
          </div>
        </div>

        {/* Mockup container removed as per user request */}
      </section>

      {/* 5-Step Sticky Scroll Features Section */}
      <section ref={stickyRef} className="sticky-features-section" style={{ height: '500vh', position: 'relative' }}>
        <div className="sticky-container">

          <div className="sticky-text-column" style={{ position: 'relative', zIndex: 10 }}>
            <motion.div className="scroll-text-block" style={{ opacity: text1Opacity, y: text1Y }}>
              <h3>Stay in the loop.</h3>
              <p>Keep a close eye on your Mac's internals without launching heavy system reports. Everything you need is one click away.</p>
            </motion.div>

            <motion.div className="scroll-text-block" style={{ opacity: text2Opacity, y: text2Y }}>
              <h3>Preserve your battery.</h3>
              <p>Lithium-ion batteries degrade faster when held at 100%. Capping your charge drastically improves your battery's long-term lifespan.</p>
            </motion.div>

            <motion.div className="scroll-text-block" style={{ opacity: text3Opacity, y: text3Y }}>
              <h3>Keep it cool.</h3>
              <p>Heat is the number one killer of batteries. Glide actively monitors thermal sensors and pauses charging if things get too hot.</p>
            </motion.div>

            <motion.div className="scroll-text-block" style={{ opacity: text4Opacity, y: text4Y }}>
              <h3>Take full control.</h3>
              <p>Don't let macOS guess your routine. Override hardware behaviors manually and command your SMC exactly how you want to.</p>
            </motion.div>

            <motion.div className="scroll-text-block" style={{ top: '25%', opacity: text5Opacity, y: text5Y }}>
              <h3 style={{ margin: 0 }}>Zero compromises.</h3>
              
              {/* The grand finale text positioned directly beneath the box, perfectly tracking with it */}
              <motion.div 
                style={{ 
                  opacity: finalSubtitleOpacity, 
                  y: finalSubtitleY,
                  position: 'absolute',
                  top: 'calc(100% + 40px)', // Snaps right below the box
                  left: 0,
                  width: '100%',
                  fontSize: '4rem',
                  lineHeight: '1.05',
                  letterSpacing: '-0.03em', // Tight, Apple-like tracking
                  color: '#f5f5f7', // Apple silver-white
                  fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
                  fontWeight: '500' // Sleek medium weight for base text
                }}
              >
                with <span style={{ fontWeight: '700', background: 'linear-gradient(135deg, #FF2E93 0%, #FF8000 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>Glide</span><br/>
                on your Mac.
              </motion.div>
            </motion.div>
          </div>

          <div className="sticky-visual-column" style={{ position: 'relative' }}>
            <motion.div className="scroll-macbook-container" style={{ scale: macbookScale }}>
              <motion.div
                className="scroll-macbook-lid"
                style={{
                  rotateX: macbookLidAngle,
                  '--lid-edge-opacity': lidEdgeOpacity
                }}
              >
                <div className="scroll-macbook-glass">
                  {/* Glowing Apple Logo turns on as it opens */}
                  <motion.svg
                    viewBox="0 0 384 512"
                    width="40"
                    height="40"
                    style={{
                      opacity: macbookLogoOpacity,
                      filter: 'drop-shadow(0 0 10px rgba(255,255,255,0.9))',
                      fill: 'rgba(255,255,255,0.9)'
                    }}
                  >
                    <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
                  </motion.svg>
                </div>
              </motion.div>
              <div className="scroll-macbook-base">
                <div className="scroll-macbook-notch"></div>
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* FAQ & Support Section */}
      <section className="faq-section">
        <div className="faq-wrapper">
          {/* FAQ Grid */}
          <div className="faq-grid">
            <div>
              <h2 className="faq-title">FAQ</h2>
            </div>
            <div>
              <AccordionItem
                question="Does Glide work on Intel Macs?"
                answer="Glide is heavily optimized for Apple Silicon (M1/M2/M3) and interfaces with specific SMC keys that may not be available on Intel architecture."
              />
              <AccordionItem
                question="How is it better than built-in 'Optimised Battery Charging'?"
                answer="macOS Optimised Battery Charging tries to learn your routine, which often fails if you have an erratic schedule. Glide gives you deterministic, physical control over your battery's charging limits and thermal protections."
              />
              <AccordionItem
                question="Why is it not available on the Mac App Store?"
                answer="Glide requires deep system-level access to the SMC (System Management Controller) to physically halt charging and modify MagSafe behavior, which is strictly prohibited by Mac App Store sandboxing rules."
              />
              <AccordionItem
                question="Where can I find the changelog?"
                answer="All changelogs and release notes are published transparently on our GitHub releases page."
              />
            </div>
          </div>

          {/* Support Grid */}
          <div className="faq-grid">
            <div>
              <h2 className="faq-title" style={{ fontSize: 'clamp(2.5rem, 5vw, 4rem)' }}>Support</h2>
            </div>
            <div>
              <AccordionItem
                question="I've set the limit, but the battery keeps charging."
                answer="This can occasionally happen if another battery management tool (like AlDente or macOS Optimised Charging) is conflicting with Glide. Ensure you disable macOS Optimised Charging in System Settings."
              />
              <AccordionItem
                question="The battery continues to charge while the Mac is in sleep."
                answer="Glide needs to be running to enforce limits. If your Mac goes into deep sleep (hibernation), Glide cannot actively poll the SMC. We recommend keeping the laptop awake while actively managing a charging session."
              />
              <AccordionItem
                question="Why does the app not open despite appearing to work in the background?"
                answer="Glide is designed as a menu bar only app. There is no main window. Look for the Glide icon (or a battery percentage) in the top right of your macOS menu bar."
              />
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer-section">
        <div className="footer-meta">
          <p>Open source. Built with care for macOS.</p>
          <div className="footer-links">
            <a href="https://github.com/abhiswrld/glide-macos" target="_blank" rel="noreferrer">GitHub Source</a>
            <a href="https://www.linkedin.com/in/abhinav-khanna06" target="_blank" rel="noreferrer">LinkedIn</a>
            <a href="mailto:hello@glide-macos.app">Contact</a>
          </div>
        </div>
      </footer>
    </>
  )
}

export default App
