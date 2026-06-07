/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Warm clay-orange brand palette.
        primary: {
          50: '#fff7ed',
          100: '#ffedd5',
          200: '#fed7aa',
          300: '#fdba74',
          400: '#f59f5b',
          500: '#e48556',
          600: '#c96442',
          700: '#a84d34',
          800: '#843d2d',
          900: '#6b3428',
          950: '#3a1a12'
        },
        // Neutral slate palette for supporting UI.
        accent: {
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
        glass: '0 18px 50px rgba(94, 59, 35, 0.10)',
        'glass-sm': '0 8px 24px rgba(94, 59, 35, 0.08)',
        glow: '0 0 22px rgba(228, 133, 86, 0.28)',
        'glow-lg': '0 0 44px rgba(228, 133, 86, 0.34)',
        card: '0 1px 2px rgba(58, 51, 42, 0.05), 0 10px 30px rgba(106, 71, 45, 0.07)',
        'card-hover': '0 16px 44px rgba(106, 71, 45, 0.12)',
        'inner-glow': 'inset 0 1px 0 rgba(255, 250, 244, 0.72)'
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'gradient-primary': 'linear-gradient(135deg, #e48556 0%, #c96442 100%)',
        'gradient-dark': 'linear-gradient(135deg, #2d241e 0%, #14100d 100%)',
        'gradient-glass':
          'linear-gradient(135deg, rgba(255,250,244,0.72) 0%, rgba(255,247,237,0.48) 100%)',
        'mesh-gradient':
          'radial-gradient(at 24% 12%, rgba(228, 133, 86, 0.13) 0px, transparent 44%), radial-gradient(at 82% 4%, rgba(201, 100, 66, 0.10) 0px, transparent 42%), radial-gradient(at 5% 54%, rgba(253, 186, 116, 0.10) 0px, transparent 46%)'
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
          '0%': { boxShadow: '0 0 20px rgba(228, 133, 86, 0.24)' },
          '100%': { boxShadow: '0 0 30px rgba(228, 133, 86, 0.38)' }
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
