# SpellBot

A modern web application built with React, TypeScript, and Supabase.

## 🚀 Features

- Built with React and TypeScript
- Styled with Tailwind CSS
- State management using Zustand
- Authentication and database powered by Supabase
- OpenAI integration
- Internationalization support (i18n)

## 🛠️ Tech Stack

- **Frontend Framework**: React 18
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: Zustand
- **Backend**: Supabase
- **AI Integration**: OpenAI
- **Build Tool**: Vite
- **Routing**: React Router
- **Icons**: Lucide React

## 📦 Installation

1. Clone the repository:
```bash
git clone [repository-url]
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the root directory with the necessary environment variables:
```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
VITE_OPENAI_API_KEY=your_openai_api_key
```

4. Start the development server:
```bash
npm run dev
```

## 🏗️ Project Structure

```
src/
├── components/     # Reusable UI components
├── hooks/         # Custom React hooks
├── i18n/          # Internationalization files
├── lib/           # Utility functions and configurations
├── pages/         # Page components
├── services/      # API and external service integrations
├── stores/        # Zustand store definitions
└── types/         # TypeScript type definitions
```

## 🧪 Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run lint` - Run ESLint
- `npm run preview` - Preview production build

## 📝 License

This project is licensed under the MIT License. See the `LICENSE` file for details.