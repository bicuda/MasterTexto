import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Editor } from './components/Editor';
import { generateId } from './lib/id';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to={`/${generateId()}`} replace />} />
        <Route path="/:roomId" element={<Editor />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
