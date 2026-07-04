/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Doit brand palette: Claude-like warm paper neutrals with pine-green contrast.
        primary: {
          50: '#fbfaf6',
          100: '#f3eee6',
          200: '#e6dbcf',
          300: '#d4c4b5',
          400: '#bba28e',
          500: '#9a7b66',
          600: '#7a5e4d',
          700: '#5d473b',
          800: '#44342c',
          900: '#30241f',
          950: '#1d1714'
        },
        // Pine green contrast for actions and identity accents.
        accent: {
          50: '#eef8ef',
          100: '#d7efda',
          200: '#b2dfb9',
          300: '#83c990',
          400: '#55ad6e',
          500: '#2f8f5b',
          600: '#207548',
          700: '#1b5d3c',
          800: '#184a33',
          900: '#153d2d',
          950: '#0b231a'
        },
        dark: {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
          950: '#020617'
        }
      },
      fontFamily: {
        sans: [
          'system-ui',
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'Helvetica Neue',
          'Arial',
          'PingFang SC',
          'Hiragino Sans GB',
          'Microsoft YaHei',
          'sans-serif'
        ],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace']
      },
      boxShadow: {
        glass: '0 18px 50px rgba(68, 52, 44, 0.07)',
        'glass-sm': '0 8px 24px rgba(68, 52, 44, 0.055)',
        glow: '0 0 22px rgba(154, 123, 102, 0.14)',
        'glow-lg': '0 0 44px rgba(47, 143, 91, 0.24)',
        card: '0 1px 2px rgba(40, 49, 38, 0.04), 0 10px 30px rgba(68, 52, 44, 0.055)',
        'card-hover': '0 16px 44px rgba(68, 52, 44, 0.08)',
        'inner-glow': 'inset 0 1px 0 rgba(253, 250, 244, 0.86)'
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'gradient-primary': 'linear-gradient(135deg, #9a7b66 0%, #2f8f5b 100%)',
        'gradient-dark': 'linear-gradient(135deg, #251c16 0%, #14100d 100%)',
        'gradient-glass':
          'linear-gradient(135deg, rgba(253,252,248,0.86) 0%, rgba(250,249,245,0.62) 100%)',
        'mesh-gradient':
          'linear-gradient(120deg, rgba(230, 219, 207, 0.18), transparent 42%), linear-gradient(180deg, rgba(47, 143, 91, 0.035), transparent 38%), linear-gradient(rgba(93, 71, 59, 0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(93, 71, 59, 0.018) 1px, transparent 1px)'
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'slide-in-right': 'slideInRight 0.3s ease-out',
        'scale-in': 'scaleIn 0.2s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        shimmer: 'shimmer 2s linear infinite',
        glow: 'glow 2s ease-in-out infinite alternate'
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' }
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideInRight: {
          '0%': { opacity: '0', transform: 'translateX(20px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' }
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' }
        },
        glow: {
          '0%': { boxShadow: '0 0 20px rgba(154, 123, 102, 0.12)' },
          '100%': { boxShadow: '0 0 30px rgba(47, 143, 91, 0.28)' }
        }
      },
      backdropBlur: {
        xs: '2px'
      },
      borderRadius: {
        '4xl': '2rem'
      }
    }
  },
  plugins: []
}
