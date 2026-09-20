/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: {
        display: ['Syne', 'system-ui', 'sans-serif'],
        sans: ['DM Sans', 'system-ui', 'sans-serif'],
      },
      colors: {
        ink: '#0c1222',
        mist: '#e8eef8',
        tide: '#1a6b5c',
        tideBright: '#2a9d8f',
        sand: '#f0a05a',
        dusk: '#1e2a44',
      },
      boxShadow: {
        glow: '0 0 60px rgba(42, 157, 143, 0.18)',
      },
      backgroundImage: {
        mesh: 'radial-gradient(ellipse 80% 60% at 20% 10%, rgba(42,157,143,0.28), transparent), radial-gradient(ellipse 60% 50% at 85% 20%, rgba(240,160,90,0.18), transparent), radial-gradient(ellipse 50% 40% at 50% 90%, rgba(30,42,68,0.55), transparent)',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-8px)' },
        },
      },
      animation: {
        float: 'float 6s ease-in-out infinite',
      },
    },
  },
  plugins: [],
}
