import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { DockQueuePage } from '../modules/dock-queue';
import { PickStagePage } from '../modules/pick-stage';

const router = createBrowserRouter([{
  path: '/', element: <AppLayout />,
  children: [
    { index: true, element: <Navigate to="/dock" replace /> },
    { path: 'dock', element: <DockQueuePage /> },
    { path: 'pick', element: <PickStagePage /> },
  ],
}]);
export function AppRouter() { return <RouterProvider router={router} />; }
