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
  const text1Opacity = useTransform(stickyScroll, [0, 0.05, 0.15, 0.2], [0, 1, 1, 0])
  const text1Y = useTransform(stickyScroll,       [0, 0.05, 0.15, 0.2], [50, 0, 0, -50])

  const text2Opacity = useTransform(stickyScroll, [0.2, 0.25, 0.35, 0.4], [0, 1, 1, 0])
  const text2Y = useTransform(stickyScroll,       [0.2, 0.25, 0.35, 0.4], [50, 0, 0, -50])

  const text3Opacity = useTransform(stickyScroll, [0.4, 0.45, 0.55, 0.6], [0, 1, 1, 0])
  const text3Y = useTransform(stickyScroll,       [0.4, 0.45, 0.55, 0.6], [50, 0, 0, -50])
  
  const text4Opacity = useTransform(stickyScroll, [0.6, 0.65, 0.75, 0.8], [0, 1, 1, 0])
  const text4Y = useTransform(stickyScroll,       [0.6, 0.65, 0.75, 0.8], [50, 0, 0, -50])

  const text5Opacity = useTransform(stickyScroll, [0.8, 0.85, 0.95, 1], [0, 1, 1, 0])
  const text5Y = useTransform(stickyScroll,       [0.8, 0.85, 0.95, 1], [50, 0, 0, -50])
  
  // Feature Cards Crossfade Opacities and Scales
  const card1Opacity = useTransform(stickyScroll, [0, 0.05, 0.15, 0.2], [0, 1, 1, 0])
  const card1Scale = useTransform(stickyScroll,   [0, 0.05, 0.15, 0.2], [0.9, 1, 1, 1.1])
  
  const card2Opacity = useTransform(stickyScroll, [0.2, 0.25, 0.35, 0.4], [0, 1, 1, 0])
  const card2Scale = useTransform(stickyScroll,   [0.2, 0.25, 0.35, 0.4], [0.9, 1, 1, 1.1])
  
  const card3Opacity = useTransform(stickyScroll, [0.4, 0.45, 0.55, 0.6], [0, 1, 1, 0])
  const card3Scale = useTransform(stickyScroll,   [0.4, 0.45, 0.55, 0.6], [0.9, 1, 1, 1.1])
  
  const card4Opacity = useTransform(stickyScroll, [0.6, 0.65, 0.75, 0.8], [0, 1, 1, 0])
  const card4Scale = useTransform(stickyScroll,   [0.6, 0.65, 0.75, 0.8], [0.9, 1, 1, 1.1])

  const card5Opacity = useTransform(stickyScroll, [0.8, 0.85, 0.95, 1], [0, 1, 1, 0])
  const card5Scale = useTransform(stickyScroll,   [0.8, 0.85, 0.95, 1], [0.9, 1, 1, 1.1])

  return (
    <>
      {/* Navigation */}
      <nav className="nav-container">
        <div className="nav-content">
          <div className="nav-logo">
            <div className="logo-icon">
              <Zap size={14} fill="currentColor" />
            </div>
            <span>Glide</span>
          </div>
          <a href="https://github.com/abhiswrld/glide-macos/releases/latest/download/Glide.dmg" className="btn-primary btn-small">
            Download
          </a>
        </div>
      </nav>
      
      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-content">
          <h1 className="hero-title">A native macOS<br />battery monitor.</h1>
          <p className="hero-subtitle">
            Zero CPU overhead. Precise telemetry. Advanced features like heat protection and MagSafe control, built directly on Apple's SMC.
          </p>
          <div className="hero-cta">
            <a href="https://github.com/abhiswrld/glide-macos/releases/latest/download/Glide.dmg" className="btn-primary btn-large">
              Download for Mac
            </a>
            <a href="https://github.com/abhiswrld/glide-macos" target="_blank" rel="noreferrer" className="btn-secondary">
              View Source
            </a>
          </div>
        </div>

        {/* Scaled down container dropping from the "menu bar" */}
        <motion.div className="mockup-container" style={{ y: mockupY, scale: mockupScaleSpring }}>
          <img src="/shot1-stats.png" alt="Glide Interface" />
        </motion.div>
        
      </section>

      {/* 5-Step Sticky Scroll Features Section */}
      <section ref={stickyRef} className="sticky-features-section" style={{ height: '500vh' }}>
        <div className="sticky-container">
          
          <div className="sticky-text-column">
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

            <motion.div className="scroll-text-block" style={{ opacity: text5Opacity, y: text5Y }}>
              <h3>Zero compromises.</h3>
              <p>Built purely in native Swift, Glide is engineered to be as lightweight as possible. It runs completely invisibly in the background.</p>
            </motion.div>
          </div>

          <div className="sticky-visual-column">
            
            <motion.div className="feature-glass-card" style={{ opacity: card1Opacity, scale: card1Scale }}>
               <div className="feature-glass-icon"><Activity size={40} /></div>
               <h4>Real-time Telemetry</h4>
               <p>Monitor live wattage, cycle counts, and capacity.</p>
            </motion.div>

            <motion.div className="feature-glass-card" style={{ opacity: card2Opacity, scale: card2Scale }}>
               <div className="feature-glass-icon"><BatteryCharging size={40} /></div>
               <h4>Charge Limiting</h4>
               <p>Set a maximum charge limit like 80%.</p>
            </motion.div>

            <motion.div className="feature-glass-card" style={{ opacity: card3Opacity, scale: card3Scale }}>
               <div className="feature-glass-icon"><Shield size={40} /></div>
               <h4>Heat Protection</h4>
               <p>Automatically pause charging on thermal spikes.</p>
            </motion.div>

            <motion.div className="feature-glass-card" style={{ opacity: card4Opacity, scale: card4Scale }}>
               <div className="feature-glass-icon"><Settings size={40} /></div>
               <h4>Advanced SMC Control</h4>
               <p>Force discharge and modify MagSafe LEDs.</p>
            </motion.div>

            <motion.div className="feature-glass-card" style={{ opacity: card5Opacity, scale: card5Scale }}>
               <div className="feature-glass-icon"><Cpu size={40} /></div>
               <h4>Highly Optimized</h4>
               <p>0.0% CPU usage. Native, efficient, and fast.</p>
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
            <a href="mailto:hello@glide-macos.app">Contact</a>
          </div>
        </div>
      </footer>
    </>
  )
}

export default App
