import { Link } from 'react-router-dom'

const features = [
  {
    icon: '📓',
    title: 'Daily Logging',
    description: 'Capture your mood, stress, and thoughts every day with guided prompts.',
  },
  {
    icon: '🤖',
    title: 'AI Predictions',
    description: 'Get personalized insights and forecasts based on your logged patterns.',
  },
  {
    icon: '🔄',
    title: 'Habit Tweaks',
    description: 'Automated suggestions to adjust your habits for better wellbeing.',
  },
  {
    icon: '🌍',
    title: 'Global Mirror',
    description: 'See how your mood compares with others around the world in real time.',
  },
  {
    icon: '🎁',
    title: 'ECHO Tokens',
    description: "Send and receive ECHO tokens to celebrate each other's growth.",
  },
  {
    icon: '📊',
    title: 'Analytics',
    description: 'Beautiful charts and reports to track your progress over time.',
  },
]

const testimonials = [
  {
    name: 'Amara K.',
    text: 'EchoMirror helped me spot stress patterns I never noticed. Game changer.',
  },
  {
    name: 'James O.',
    text: 'The AI habit suggestions are surprisingly accurate. I sleep better now.',
  },
  {
    name: 'Sana R.',
    text: "Love the global mirror feature — feels good to know I'm not alone.",
  },
]

export function LandingPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white">

      {/* Nav */}
      <nav className="sticky top-0 z-50 backdrop-blur-md bg-white/80 border-b border-gray-100 px-6 py-4">
        <div className="max-w-5xl mx-auto flex items-center justify-between">
          <span className="text-xl font-bold text-gray-900">EchoMirror Butler</span>
          <div className="flex items-center gap-3">
            <Link
              to="/login"
              className="text-sm text-gray-600 hover:text-gray-900 px-4 py-2 rounded-lg transition-colors"
            >
              Sign in
            </Link>
            <Link
              to="/signup"
              className="text-sm bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors"
            >
              Get started
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="max-w-5xl mx-auto px-6 pt-20 pb-16 text-center">
        <h1 className="text-5xl font-bold text-gray-900 leading-tight mb-4">
          Your personal growth,{' '}
          <span className="text-blue-600">understood</span>
        </h1>
        <p className="text-lg text-gray-500 max-w-xl mx-auto mb-8">
          EchoMirror Butler combines daily logging, AI predictions, and automated
          habit tweaks to help you become the best version of yourself.
        </p>
        <div className="flex items-center justify-center gap-3">
          <Link
            to="/signup"
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl font-semibold transition-colors"
          >
            Start for free
          </Link>
          <Link
            to="/login"
            className="text-gray-600 hover:text-gray-900 px-6 py-3 rounded-xl font-semibold border border-gray-200 hover:border-gray-300 transition-colors"
          >
            Sign in
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="max-w-5xl mx-auto px-6 pb-20">
        <div className="mb-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">
            Every tool you need to understand yourself
          </h2>
          <p className="text-gray-500">
            Built for people serious about personal growth.
          </p>
        </div>
        {/*
          lp-features-grid: margin-top kept at ~2rem (mb-8 on header above)
          to avoid dead space between heading and cards — fixes #379
        */}
        <div className="lp-features-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f) => (
            <div
              key={f.title}
              className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow"
            >
              <div className="text-3xl mb-3">{f.icon}</div>
              <h3 className="font-semibold text-gray-900 mb-1">{f.title}</h3>
              <p className="text-sm text-gray-500 leading-relaxed">{f.description}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Health awareness */}
      <section className="bg-blue-50 border-y border-blue-100">
        <div className="max-w-5xl mx-auto px-6 py-16">
          <div className="mb-8">
            <h2 className="text-3xl font-bold text-gray-900 mb-2">
              Built with your wellbeing in mind
            </h2>
            <p className="text-gray-500">
              We take mental health seriously — no dark patterns, no pressure.
            </p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
            {[
              { icon: '🔒', title: 'Private by default', desc: 'Your data is yours. We never sell it.' },
              { icon: '🧘', title: 'No streaks pressure', desc: 'Log when you want. No guilt trips.' },
              { icon: '💬', title: 'Evidence-based', desc: 'Suggestions grounded in psychology research.' },
            ].map((item) => (
              <div key={item.title} className="bg-white rounded-2xl p-6 border border-blue-100 shadow-sm">
                <div className="text-3xl mb-3">{item.icon}</div>
                <h3 className="font-semibold text-gray-900 mb-1">{item.title}</h3>
                <p className="text-sm text-gray-500 leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="max-w-5xl mx-auto px-6 py-16">
        <div className="mb-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">
            What our users say
          </h2>
          <p className="text-gray-500">Real people, real growth.</p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
          {testimonials.map((t) => (
            <div key={t.name} className="bg-white border border-gray-100 rounded-2xl p-6 shadow-sm">
              <p className="text-gray-700 mb-4 leading-relaxed">"{t.text}"</p>
              <p className="text-sm font-semibold text-gray-900">{t.name}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-100 py-8 text-center text-sm text-gray-400">
        © {new Date().getFullYear()} EchoMirror Butler. All rights reserved.
      </footer>
    </div>
  )
}
