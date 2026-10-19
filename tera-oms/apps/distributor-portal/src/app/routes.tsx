import { createBrowserRouter, RouterProvider } from 'react-router-dom';
const router = createBrowserRouter([{ path: '/', element: <div className="p-6">Coming soon</div> }]);
export function AppRouter() { return <RouterProvider router={router} />; }
